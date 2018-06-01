from urllib.request import urlopen
from urllib.request import Request
import urllib.error as error
import os

data_template_default = '{{"title": "{}","text": "{}"}}'
hook_url = None
HOOK_URL_NAME = "hook_url"


def initial():
    # set up hook url
    url = os.environ.get(HOOK_URL_NAME, "").strip()
    if len(url) > 0:
        global hook_url
        hook_url = url
    else:
        raise Exception('No hook url provided via Environment', HOOK_URL_NAME)


def send_hook(event, context):
    headers = {'Content-Type': 'application/json'}
    for record in event['Records']:
        sns = record['Sns']
        title = sns['Subject']
        message = sns['Message']
        data = data_template_default.format(title, message)
        print(data)
        data_encoded = data.encode('utf-8')
        try:
            req = Request(hook_url, headers=headers, method='POST',
                          data=data_encoded)
            res = urlopen(req)
            print(res)
        except error.HTTPError as e:
            raise Exception('status:', e.code, 'reason:', e.reason, 'url:', e.url)


def handler(event, context):
    """
    Main Lambda function
    """
    initial()
    send_hook(event, context)
