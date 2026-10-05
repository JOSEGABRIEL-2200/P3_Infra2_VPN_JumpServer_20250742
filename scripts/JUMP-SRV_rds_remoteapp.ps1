# =====================================================================
# JUMP-SRV_rds_remoteapp.ps1 - P3 Infraestructura 2
# Jose Gabriel Feliz Maria - 2025-0742
#
# Jump Server: Windows Server 2022 (WIN-3PRJM03EJ6S.jose.gabriel),
# controlador del dominio jose.gabriel, IP 10.7.42.130/29.
# El rol RDS se instalo por asistente (Server Manager -> Add roles and
# features -> Remote Desktop Services installation -> Quick Start ->
# Session-based): RD Connection Broker, RD Web Access y RD Session Host.
# Despues se agrego RD Gateway desde Deployment Overview.
# Este script deja documentado lo que se configuro por PowerShell.
# No contiene contrasenas.
# =====================================================================
Import-Module RemoteDesktop
$fqdn = 'WIN-3PRJM03EJ6S.jose.gabriel'
$c    = 'QuickSessionCollection'

# ---------- 1. Certificado autofirmado para los 4 roles de RDS ----------
New-Item -ItemType Directory -Path C:\certs -Force | Out-Null
$cert = New-SelfSignedCertificate -DnsName $fqdn -CertStoreLocation Cert:\LocalMachine\My `
          -NotAfter (Get-Date).AddYears(2) -Provider 'Microsoft RSA SChannel Cryptographic Provider' `
          -KeySpec KeyExchange -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy Exportable
Export-Certificate -Cert $cert -FilePath C:\certs\jump-rds.cer | Out-Null      # parte publica, para los clientes
Import-Certificate -FilePath C:\certs\jump-rds.cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
foreach ($r in 'RDGateway','RDWebAccess','RDRedirector','RDPublishing') {
    Set-RDCertificate -Role $r -Thumbprint $cert.Thumbprint -ConnectionBroker $fqdn -Force
}
Get-RDCertificate -ConnectionBroker $fqdn | Format-Table Role, Level, Subject -AutoSize

# ---------- 2. RemoteApp publicadas ----------
# Se quitan las de ejemplo del Quick Start (Calculator, Paint, WordPad).
Get-RDRemoteApp -CollectionName $c | ForEach-Object { Remove-RDRemoteApp -CollectionName $c -Alias $_.Alias -Force }

# Web: Edge en modo aplicacion, abre solo el Sistema de Caja del Web Server.
New-RDRemoteApp -CollectionName $c -Alias 'SistemaCaja' -DisplayName 'Sistema de Caja (Web)' `
    -FilePath 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' `
    -CommandLineSetting Require -RequiredCommandLine '--no-first-run --app=https://10.7.42.138' | Out-Null

# RDP: cliente de Escritorio remoto hacia el Web Server.
New-RDRemoteApp -CollectionName $c -Alias 'RDP' -DisplayName 'Escritorio remoto (RDP)' `
    -FilePath 'C:\Windows\System32\mstsc.exe' `
    -CommandLineSetting Require -RequiredCommandLine '/v:10.7.42.138' | Out-Null

# ---------- 3. Grupos y visibilidad por usuario ----------
New-ADGroup -Name 'GRP_SinPrivilegios' -GroupScope Global -GroupCategory Security -Path 'CN=Users,DC=jose,DC=gabriel' `
    -Description 'P3 Infra 2: usuarios sin privilegios (solo RemoteApp Web)'
New-ADGroup -Name 'GRP_Privilegiados' -GroupScope Global -GroupCategory Security -Path 'CN=Users,DC=jose,DC=gabriel' `
    -Description 'P3 Infra 2: usuarios con privilegios (RemoteApp Web, PuTTY y RDP)'

# Web la ven los dos grupos; RDP (y PuTTY) solo el grupo con privilegios.
Set-RDRemoteApp -CollectionName $c -Alias 'SistemaCaja' -UserGroups 'JOSE\GRP_SinPrivilegios','JOSE\GRP_Privilegiados'
Set-RDRemoteApp -CollectionName $c -Alias 'RDP'         -UserGroups 'JOSE\GRP_Privilegiados'
Get-RDRemoteApp -CollectionName $c | Format-Table Alias, DisplayName, UserGroups -AutoSize

# ---------- 4. Usuarios del dominio en cada grupo ----------
# Los usuarios ya existian en el dominio; solo se agregan a los grupos.
Add-ADGroupMember -Identity 'GRP_SinPrivilegios' -Members 'pedrito'   # usuario sin privilegios
Add-ADGroupMember -Identity 'GRP_Privilegiados'  -Members 'gabriel'   # usuario con privilegios

# ---------- 5. PuTTY (requiere Internet temporal en el servidor) ----------
# Instalador oficial; se comprueba la firma digital antes de instalar.
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
$h = Invoke-WebRequest 'https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html' -UseBasicParsing
$u = ($h.Links.href | Where-Object { $_ -match 'w64/putty-64bit-.*-installer\.msi$' } | Select-Object -First 1)
Invoke-WebRequest $u -OutFile C:\certs\putty.msi
(Get-AuthenticodeSignature C:\certs\putty.msi).Status          # debe decir Valid (firmado por Simon Tatham)
Start-Process msiexec -ArgumentList '/i C:\certs\putty.msi /qn /norestart' -Wait
New-RDRemoteApp -CollectionName $c -Alias 'PuTTY' -DisplayName 'PuTTY (SSH)' `
    -FilePath 'C:\Program Files\PuTTY\putty.exe' `
    -CommandLineSetting Require -RequiredCommandLine '-ssh admincaja@10.7.42.138' `
    -UserGroups 'JOSE\GRP_Privilegiados' | Out-Null

# ---------- 6. RemoteApp Web Client (HTML5) ----------
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
Install-Module -Name PowerShellGet -Force -AllowClobber
# Lo siguiente va en una sesion nueva de PowerShell (para que cargue el PowerShellGet actualizado):
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Install-Module -Name RDWebClientManagement -Force -AcceptLicense; Install-RDWebClientPackage; Import-RDWebClientBrokerCert C:\certs\jump-rds.cer; Publish-RDWebClientPackage -Type Production -Latest; Get-RDWebClientPackage"
# Queda en: https://WIN-3PRJM03EJ6S.jose.gabriel/RDWeb/webclient/index.html

# ---------- 7. Certificado publico disponible para los clientes ----------
Copy-Item C:\certs\jump-rds.cer C:\inetpub\wwwroot\jump-rds.cer -Force
# Nota: IIS no sirvio el archivo (error 404). Los equipos de usuario obtienen el
# certificado del saludo TLS con scripts/cliente_confiar_certificado_jump.ps1.

# ---------- 8. Confiar en el certificado del Web Server ----------
# Para que la RemoteApp "Sistema de Caja (Web)" abra sin aviso de certificado.
$tcp = New-Object Net.Sockets.TcpClient('10.7.42.138',443)
$ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, ({$true} -as [Net.Security.RemoteCertificateValidationCallback]))
$ssl.AuthenticateAsClient('10.7.42.138')
$wc  = New-Object Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
$ssl.Close(); $tcp.Close()
[IO.File]::WriteAllBytes('C:\certs\web-caja.cer', $wc.Export('Cert'))
Import-Certificate -FilePath C:\certs\web-caja.cer -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
(Invoke-WebRequest https://10.7.42.138 -UseBasicParsing).StatusCode      # 200 = HTTPS validado

# Se evita el aviso de traduccion de Edge en la RemoteApp.
Set-RDRemoteApp -CollectionName $c -Alias 'SistemaCaja' `
    -RequiredCommandLine '--no-first-run --disable-features=Translate --app=https://10.7.42.138'
