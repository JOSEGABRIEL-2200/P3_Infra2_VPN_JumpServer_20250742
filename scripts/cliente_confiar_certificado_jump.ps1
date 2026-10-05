# =====================================================================
# cliente_confiar_certificado_jump.ps1 - P3 Infraestructura 2
# Jose Gabriel Feliz Maria - 2025-0742
#
# Se ejecuta UNA vez en cada equipo de usuario (PC con privilegios y
# VM Windows 10 sin privilegios), en PowerShell como administrador y
# con la VPN arriba.
#   1. Resuelve el nombre del Jump Server (los usuarios usan DNS publico,
#      asi que el nombre del dominio interno se agrega al archivo hosts).
#   2. Lee el certificado autofirmado del Jump Server directamente del
#      saludo TLS (puerto 443) y lo agrega a las entidades de confianza,
#      para que RD Web, las RemoteApp y el cliente web abran sin errores
#      de certificado.
# No contiene contrasenas.
# =====================================================================
$fqdn = 'WIN-3PRJM03EJ6S.jose.gabriel'
$ip   = '10.7.42.130'

Add-Content C:\Windows\System32\drivers\etc\hosts "`n$ip $fqdn"

$tcp = New-Object Net.Sockets.TcpClient($ip, 443)
$ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, ({$true} -as [Net.Security.RemoteCertificateValidationCallback]))
$ssl.AuthenticateAsClient($fqdn)
$c = New-Object Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
$ssl.Close(); $tcp.Close()

[IO.File]::WriteAllBytes("$env:TEMP\jump-rds.cer", $c.Export('Cert'))
Import-Certificate -FilePath $env:TEMP\jump-rds.cer -CertStoreLocation Cert:\LocalMachine\Root

# Despues, en el navegador:
#   RD Web (clasico):      https://WIN-3PRJM03EJ6S.jose.gabriel/RDWeb
#   Cliente web (HTML5):   https://WIN-3PRJM03EJ6S.jose.gabriel/RDWeb/webclient/index.html
