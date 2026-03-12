openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/cyberstrike.key \
  -out nginx/ssl/cyberstrike.crt \
  -subj "/C=CN/ST=Cyber/L=Strike/O=AI/CN=localhost"
