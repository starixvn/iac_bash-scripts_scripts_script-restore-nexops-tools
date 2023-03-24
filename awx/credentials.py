DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': "ansibledb",
        'USER': "awx",
        'PASSWORD': "1234aa",
        'HOST': "69.0.0.20",
        'PORT': "5439",
    }
}

BROADCAST_WEBSOCKET_SECRET = "NGJ5VHhZLWdhYlB5R29ZazIyQTY="
