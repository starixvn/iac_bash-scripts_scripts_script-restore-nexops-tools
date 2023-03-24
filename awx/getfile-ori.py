#!/usr/bin/python3
import ftplib
import ssl

# Information to connect FTPD
ftpdServer = "ftpd-backup.nexdev.net"
ftpdPort = 2023
ftpdUser = "starix"
ftpdPass = "#2Z7g~kNJ$DdVpU"
context = ssl.create_default_context()
context.load_default_certs()
context.check_hostname = False
context.verify_mode = ssl.CERT_NONE
pathTool = "/envOfBackupFile/awx_postgres"

# Init connection to FTPD
ftpConnection = ftplib.FTP_TLS(context=context)
ftpConnection.set_pasv(True)
ftpConnection.connect(ftpdServer, ftpdPort)
ftpConnection.login(ftpdUser, ftpdPass)

# Change path to file name locate
ftpConnection.cwd(pathTool)

# Get latest file
folderInfo = ftpConnection.mlsd(facts=["type","modify","size"])
latestFObj = None
for file in folderInfo:
    ftype = file[1]["type"]
    if not ftype == "file":
        continue
    if latestFObj == None:
        latestFObj = file
    else:
        if latestFObj[1]["modify"] <= file[1]["modify"]:
            latestFObj = file
            
toolFileLatest = latestFObj[0]

# Download latest file
with open(toolFileLatest, 'wb') as f:
    ftpConnection.retrbinary('RETR %s' % toolFileLatest, f.write)

# Close connection FTPD
ftpConnection.quit()








