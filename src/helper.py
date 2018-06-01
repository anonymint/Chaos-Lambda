from time import strftime, gmtime

def printlog(*args):
    current = strftime("%Y-%m-%d %H:%M:%SZ", gmtime())
    print(current, *args)