import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
host=""
client.connect(hostname = host, username="", password="")
print("Connected to " + host)
print('executing command')
stdin, stdout, stderr = client.exec_command("ls -l")
for line in stdout:
	print(line.strip('\n'))
client.close()	