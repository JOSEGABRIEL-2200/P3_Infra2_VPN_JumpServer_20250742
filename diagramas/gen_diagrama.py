import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Ellipse

fig, ax = plt.subplots(figsize=(17, 11.5), dpi=150)
ax.set_xlim(0, 170); ax.set_ylim(0, 115); ax.axis("off")
fig.patch.set_facecolor("white")

INK = "#1f2937"; MUTED = "#6b7280"
C_USR = "#2563eb"; C_ADM = "#7c3aed"; C_FGT = "#dc2626"; C_SW = "#0f766e"
C_WEB = "#d97706"; C_MG = "#9ca3af"; C_OK = "#16a34a"; C_ISP = "#475569"; C_JMP = "#0369a1"


def box(x, y, w, h, title, lines, color, fs=9.0, tfs=12, face="white"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.5,rounding_size=1.8",
                                linewidth=2, edgecolor=color, facecolor=face, zorder=3))
    ax.text(x + w/2, y + h - 3.0, title, ha="center", va="center", fontsize=tfs, fontweight="bold", color=color, zorder=4)
    for i, t in enumerate(lines):
        ax.text(x + w/2, y + h - 6.8 - i*3.1, t, ha="center", va="center", fontsize=fs,
                color=INK, family="DejaVu Sans Mono", zorder=4)


def link(p1, p2, label=None, color=INK, lw=2.2, ls="-", off=(0, 1.8), fs=8.3):
    ax.plot([p1[0], p2[0]], [p1[1], p2[1]], color=color, lw=lw, ls=ls, zorder=2, solid_capstyle="round")
    if label:
        ax.text((p1[0]+p2[0])/2 + off[0], (p1[1]+p2[1])/2 + off[1], label, ha="center", va="center",
                fontsize=fs, color=MUTED, zorder=5, bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none"))


ax.text(85, 112, "P3 · Infraestructura 2 — VPN Site-to-Site y Jump Server (RDS RemoteApp)",
        ha="center", fontsize=17, fontweight="bold", color=INK)
ax.text(85, 108.2, "Jose Gabriel Feliz Maria · Matrícula 2025-0742 · Seguridad de Redes (ITLA)",
        ha="center", fontsize=10.5, color=MUTED)

# Internet / gestion
ax.add_patch(Ellipse((85, 99.5), 50, 9.5, facecolor="#f3f4f6", edgecolor=C_MG, lw=2, zorder=1))
ax.text(85, 100.9, "INTERNET (Cloud0)", ha="center", fontsize=11, fontweight="bold", color="#4b5563")
ax.text(85, 97.7, "192.168.182.0/24 · salida + gestión del FortiGate", ha="center", fontsize=8.4, color=INK,
        family="DejaVu Sans Mono")

# ISP
box(66, 70, 38, 19.5, "ISP (Cisco IOL)", ["e0/0  200.7.42.1/30", "e0/1  200.7.42.5/30",
                                          "e0/2  192.168.182.70/24", "IPs públicas · NAT"], C_ISP, tfs=11.5)

# Sitio Cliente
ax.add_patch(FancyBboxPatch((2, 20), 58, 71, boxstyle="round,pad=0.5,rounding_size=2.5",
                            linewidth=2, edgecolor=C_USR, facecolor="#eff6ff", ls="--", zorder=1))
ax.text(31, 87.6, "SITIO CLIENTE", ha="center", fontsize=12.5, fontweight="bold", color=C_USR)
box(11, 63, 40, 19.5, "R-CLIENTE (Cisco IOL)", ["e0/0 WAN  200.7.42.2/30", "e0/1 LAN  10.7.42.1/25",
                                               "DHCP VLAN 10 · NAT", "extremo Cisco de la VPN"], C_SW, tfs=11.5)
box(11, 46, 40, 10.5, "SW-A (Cisco IOL L2)", ["VLAN 10 · port-security"], C_SW, tfs=11)
box(5, 23, 25, 16.5, "Usuario sin privilegios", ["VM Windows 10", "DHCP 10.7.42.10", "Cloud2 · e0/1"], C_USR, fs=8.4, tfs=9.6)
box(32, 23, 25, 16.5, "Usuario con privilegios", ["PC host", "DHCP 10.7.42.20", "Cloud4 · e0/2"], C_ADM, fs=8.4, tfs=9.6)

# Sitio Servidor
ax.add_patch(FancyBboxPatch((110, 20), 58, 71, boxstyle="round,pad=0.5,rounding_size=2.5",
                            linewidth=2, edgecolor=C_FGT, facecolor="#fef2f2", ls="--", zorder=1))
ax.text(139, 87.6, "SITIO SERVIDOR", ha="center", fontsize=12.5, fontweight="bold", color=C_FGT)
box(118, 60, 42, 22.5, "FGT-SERVIDOR (FortiGate)", ["port1 WAN   200.7.42.6/30", "port2 JUMP  10.7.42.129/29",
                                                   "port3 WEB   10.7.42.137/29", "3 políticas · 3 rutas",
                                                   "extremo FortiGate de la VPN"], C_FGT, tfs=11.5)
box(112, 23, 26, 26, "JUMP SERVER", ["Windows Server", "10.7.42.130/29", "RDS RemoteApp", "+ Web Client",
                                     "LAN propia", "Cloud3 · port2"], C_JMP, fs=8.4, tfs=10.5)
box(140, 23, 26, 26, "WEB SERVER", ["Sistema de Caja", "10.7.42.138/29", "HTTPS · RDP", "SSH",
                                    "LAN propia", "Cloud1 · port3"], C_WEB, fs=8.4, tfs=10.5)

# Enlaces
link((85, 90), (85, 94.6), "e0/2", off=(5, 0))
link((51.5, 76), (65.5, 78), "e0/0 ↔ e0/0", off=(0, 2.6), fs=7.6)
link((104.5, 78), (117.5, 76), "e0/1 ↔ port1", off=(0, 2.6), fs=7.6)
link((31, 62.5), (31, 57), "e0/1 ↔ e0/0", off=(9, 0), fs=7.6)
link((22, 45.5), (18, 40), "e0/1", off=(-4.5, 0))
link((40, 45.5), (44, 40), "e0/2", off=(4.5, 0))
link((130, 59.5), (125, 49.5), "port2", off=(-5, 0))
link((148, 59.5), (153, 49.5), "port3", off=(5, 0))

# Tunel VPN
ax.plot([51.5, 60, 110, 117.5], [66, 61, 61, 66], color=C_OK, lw=3, ls=(0, (5, 3)), zorder=2)
ax.text(85, 63.6, "Túnel VPN IPsec Site-to-Site", ha="center", fontsize=10.5, fontweight="bold", color=C_OK,
        bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none"), zorder=5)
ax.text(85, 58.2, "10.7.42.0/25  ⇄  10.7.42.128/28", ha="center", fontsize=8.6, color=INK,
        family="DejaVu Sans Mono", bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none"), zorder=5)

# Leyenda de politicas
ax.add_patch(FancyBboxPatch((2, 1.5), 166, 14.5, boxstyle="round,pad=0.4,rounding_size=1.5",
                            linewidth=1.2, edgecolor=C_MG, facecolor="#f9fafb", zorder=1))
rows = [
    (C_FGT, "Usuario sin privilegios → Servidores", "SSH DENEGADO por política explícita (registrado)"),
    (C_OK, "VPN (VLAN 10) → Jump Server", "único destino permitido por la VPN: HTTPS y RDP (RemoteApp y Web Client)"),
    (C_WEB, "Jump Server → Web Server", "solo HTTPS, RDP y SSH · todo lo demás cae en Implicit Deny"),
]
for i, (c, a, b) in enumerate(rows):
    y = 12.6 - i*3.9
    ax.text(4.5, y, a, fontsize=9.4, fontweight="bold", color=c, va="center")
    ax.text(60, y, b, fontsize=8.9, color=INK, va="center")

plt.savefig("topologia_p3_infra2.png", bbox_inches="tight", facecolor="white")
print("ok")
