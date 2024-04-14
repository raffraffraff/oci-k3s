data "http" "ip" {
  url = "https://ifconfig.me/ip"
}


# reference it using: data.http.ip.response_body
