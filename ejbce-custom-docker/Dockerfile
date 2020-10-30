FROM primekey/ejbca-ce

MAINTAINER samiahmedshaik@gmail.com

COPY web.properties /opt/primekey/ejbca/conf/
COPY after-deployed.sh /opt/primekey/bin/internal
COPY after-deployed-app-create-certificate.sh /opt/primekey/bin/internal
COPY after-deployed-app-post-tls.sh /opt/primekey/bin/internal

