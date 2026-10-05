#!/bin/bash
# =====================================================================
# kali_web_server_infra2.sh - P3 Infraestructura 2
# Jose Gabriel Feliz Maria - 2025-0742
#
# Convierte el Kali (VMnet2 / Cloud1, LAN_WEB del FortiGate) en el
# Web Server "Sistema de Caja" con los tres servicios que el Jump Server
# puede usar: HTTPS (Apache), RDP (xrdp) y SSH.
#   IP 10.7.42.138/29 - gateway 10.7.42.137 (port3 del FortiGate)
# Usa un perfil de red propio (infra2-web) para no tocar el de la Infra 1.
# El usuario admincaja se crea aparte con "sudo adduser admincaja"
# (su contrasena no se guarda en ningun archivo).
# Uso: sudo bash kali_web_server_infra2.sh
# =====================================================================
set -e
if [ "$(id -u)" -ne 0 ]; then echo "Ejecuta con: sudo bash $0"; exit 1; fi

# ---------- Red: perfil propio de la Infra 2 ----------
nmcli -t -f NAME con show | grep -qx infra2-web || \
  nmcli con add type ethernet ifname eth1 con-name infra2-web ipv4.method manual \
    ipv4.addresses 10.7.42.138/29 ipv4.gateway 10.7.42.137 ipv4.dns 8.8.8.8 \
    connection.autoconnect-priority 10 ipv4.route-metric 50
nmcli con mod infra2-web ipv4.route-metric 50   # responde siempre por eth1 aunque exista otro adaptador
nmcli con up infra2-web

# ---------- Paquetes para RDP (requiere Internet temporal) ----------
# El Kali usa GNOME sobre Wayland y no trae el servidor Xorg que xrdp necesita,
# asi que se instalan xorgxrdp y un escritorio liviano (XFCE) para las sesiones RDP.
apt-get update
apt-get install -y xrdp xorgxrdp xfce4-session xfwm4 xfdesktop4 xfce4-panel xfce4-terminal dbus-x11
# El Escritorio remoto integrado de GNOME ocupa el puerto 3389: se desactiva.
sudo -u "${SUDO_USER:-jose}" XDG_RUNTIME_DIR="/run/user/$(id -u "${SUDO_USER:-jose}")" \
  systemctl --user mask --now gnome-remote-desktop.service 2>/dev/null || true
systemctl disable --now gnome-remote-desktop.service 2>/dev/null || true
pkill -f gnome-remote-desktop-daemon 2>/dev/null || true

# ---------- SSH y RDP ----------
id admincaja >/dev/null 2>&1 || { echo "Crea primero el usuario: sudo adduser admincaja"; exit 1; }
echo startxfce4 > /home/admincaja/.xsession
chown admincaja:admincaja /home/admincaja/.xsession
adduser xrdp ssl-cert >/dev/null
systemctl enable --now ssh
systemctl enable --now xrdp
systemctl restart xrdp

# ---------- HTTPS: Sistema de Caja ----------
mkdir -p /var/www/caja0742
cat > /var/www/caja0742/index.html <<'EOF'
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>Sistema de Caja</title>
<style>
body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#0f172a;color:#e2e8f0}
header{background:#15803d;padding:28px 40px}
h1{margin:0;font-size:34px} main{padding:30px 40px}
.card{background:#1e293b;border-radius:10px;padding:18px 22px;margin:14px 0;max-width:760px}
td,th{padding:6px 14px;text-align:left} small{color:#94a3b8}
</style></head><body>
<header><h1>Sistema de Caja</h1><div>Punto de venta y facturacion</div></header>
<main>
<div class="card"><b>Servidor:</b> web-caja 10.7.42.138 &nbsp;|&nbsp; <b>Red:</b> LAN_WEB 10.7.42.136/29 &nbsp;|&nbsp; <b>Gateway:</b> FortiGate 10.7.42.137</div>
<div class="card"><table><tr><th>Producto</th><th>Existencia</th><th>Precio</th></tr>
<tr><td>Router Cisco ISR</td><td>10</td><td>RD$ 850.00</td></tr>
<tr><td>Switch 24 puertos</td><td>25</td><td>RD$ 320.00</td></tr>
<tr><td>FortiGate 40F</td><td>5</td><td>RD$ 1,200.00</td></tr></table></div>
<div class="card">Este servidor solo es accesible desde el Jump Server, por HTTPS, RDP y SSH.</div>
<small>Jose Gabriel Feliz Maria - Matricula 2025-0742 - Seguridad de Redes (ITLA) - P3 Infraestructura 2</small>
</main></body></html>
EOF
[ -f /etc/ssl/certs/caja0742.crt ] || openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/caja0742.key -out /etc/ssl/certs/caja0742.crt \
  -subj "/CN=web-caja.itla0742.local" \
  -addext "subjectAltName=DNS:web-caja.itla0742.local,IP:10.7.42.138"
cat > /etc/apache2/sites-available/caja0742-ssl.conf <<'EOF'
<VirtualHost *:443>
    ServerName web-caja.itla0742.local
    DocumentRoot /var/www/caja0742
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/caja0742.crt
    SSLCertificateKeyFile /etc/ssl/private/caja0742.key
</VirtualHost>
EOF
a2enmod ssl >/dev/null
a2dissite default-ssl >/dev/null || true
a2ensite caja0742-ssl >/dev/null
systemctl enable apache2
systemctl restart apache2

echo
ss -tln | grep -E ':(22|443|3389)\s'
echo "Listo. Web Server 10.7.42.138: HTTPS 443, RDP 3389 y SSH 22."
