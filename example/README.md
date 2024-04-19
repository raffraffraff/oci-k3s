# Basic NGINX server with ingress
This is probably the simplest way to demonstrate how you can get an extremely simple webpage hosted on your cluster. If you run `deploy.sh` in this directory it will deploy the following resources:
- Deployment 'nginx'
  - Creates Pod 'nginx'
    - Runs the container nginx:latest
    - Adds the label 'nginx'
- Service 'nginx':
  - Exposes TCP port 80
  - Targets TCP port 80 on pods that match the label 'nginx'
- Ingress 'webserver':
  - Routing rule:
    - Host "example.com"
    - Path "/"
    - Backend service: nginx
    - Backend port: 80

Now, the host 'example.com' does not exist, but you can test it easily. Grab the public IP address of your NLB (which you'll find in the `terraform output` results for the root module) and try this curl command:

```
curl http://example.com --resolve 'example.com:80:151.183.24.123'
```

If it works, you'll see the default NGINX welcome page:
```
$ curl http://example.com

!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
