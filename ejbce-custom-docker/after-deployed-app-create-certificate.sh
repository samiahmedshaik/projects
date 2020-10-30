#!/bin/bash

##################################################################
#                                                                #
# Copyright (c) 2018-2019 PrimeKey Solutions AB.                 #
#                                                                #
# This software is free software; you can redistribute it and/or #
# modify it under the terms of the GNU Lesser General Public     #
# License as published by the Free Software Foundation; either   #
# version 2.1 of the License, or any later version.              #
#                                                                #
# See terms of license at gnu.org.                               #
#                                                                #
##################################################################

baseDir="$1"
tempDir="$2"

if [ -f ${baseDir}/bin/internal/functions-ejbca ] ; then source ${baseDir}/bin/internal/functions-ejbca ; fi

keyStoreBaseName="$3"
keyStoreJks="${keyStoreBaseName}.jks"
keyStoreStorepasswd="${keyStoreBaseName}.storepasswd"
keyStoreKeypasspwd="${keyStoreBaseName}.keypasspwd"

# Classic instantiation workflow:
instanceHostname="$(hostname --fqdn)"
managementCaUid="c-0$(dd if=/dev/urandom count=1 bs=8 2>/dev/null | hexdump -e '/1 "%02x"')"
baseDn=",O=${ORG_NAME},UID=${managementCaUid}"

# If this is a new and empty installation, setup a ${CA_NAME}
existingCas=$(ejbca_command ca listcas 2>&1 | grep 'CA Name: ' | sed 's/.*CA Name: //g')
if [ "x$existingCas" == "x" ] ; then

    ejbca_command ca init \
        --caname "${CA_NAME}" \
        --dn "\"CN=${CA_NAME}${baseDn}\"" \
        --tokenType "soft" \
        --tokenPass "null" \
        --keytype "RSA" \
        --keyspec "3072" \
        -v "3652" \
        --policy "null" \
        -s "SHA256WithRSA" \
        -type "x509"

    # Unless the user of the container has provided a better idea for authentication, we stage a classic SuperAdmin generation
    if [ -z "${INITIAL_ADMIN}" ] ; then
        superAdminEnrollmentCode="$(dd if=${SECURE_RANDOM_SOURCE} count=1 bs=18 2>/dev/null | base64 -w 0)"

        ejbca_command ra addendentity \
            --username superadmin \
            --dn "\"CN=SuperAdmin${baseDn}\"" \
            --caname "${CA_NAME}" \
            --type 1 \
            --token P12 \
            --password "${superAdminEnrollmentCode}"

        export INITIAL_ADMIN="${CA_NAME};CertificateAuthenticationToken:WITH_COMMONNAME;SuperAdmin"

        echo "
**************************************************************************************
* A fresh installation was detected and a ${CA_NAME} was created for your initial  *
* administaration of the system.                                                     *
*                                                                                    *
* Initial SuperAdmin client certificate enrollment URL (adapt port to your mapping): *
*                                                                                    *
*   URL:      https://${instanceHostname}:8443/ejbca/enrol/keystore.jsp
*   Username: superadmin                                                             *
*   Password: ${superAdminEnrollmentCode}                                               *
*                                                                                    *
* Once the P12 is downloaded, use \"${superAdminEnrollmentCode}\" to import it.           *
**************************************************************************************
" > ${tempDir}/enrollment-info.txt

    else
        echo "
*****************************************************************************************
* A fresh installation was detected and a ${CA_NAME} was created for your initial     *
* access to the system.                                                                 *
*                                                                                       *
*   URL:      https://${instanceHostname}:443/ejbca/adminweb/
*                                                                                       *
* If you use different port mapping or a proxy, please adapt the URL above accordingly. *
*****************************************************************************************
" > ${tempDir}/enrollment-info.txt
    fi
fi

# If this installation has a ${CA_NAME} we will use this to generate a certificate
existingManagementCA=$(ejbca_command ca listcas 2>&1 | grep 'CA Name: '${CA_NAME} | sed 's/.*CA Name: //g')
if [ "x$existingManagementCA" == "x$CA_NAME" ] ; then

    keyStorePassword="$(dd if=/dev/urandom count=1 bs=18 2>/dev/null | base64 -w 0)"
    endEntityName="${instanceHostname}"
    if [ "${instanceHostname}" == "ejbca" ] ; then
        # Avoid conflicts with the default EJBCA EJB CLI end entity "ejbca"
        endEntityName="ejbca-instance-tls"
    fi

    ejbca_command ra addendentity \
        --username "${endEntityName}" \
        --dn "\"CN=${instanceHostname}${baseDn}\"" \
        --caname "${CA_NAME}" \
        --type 1 \
        --token JKS \
        --password ${keyStorePassword} \
        --altname "dnsName=${instanceHostname}" \
        --certprofile SERVER

    ejbca_command ra setendentitystatus \
        --username "${endEntityName}" \
        -S 10

    ejbca_command ra setclearpwd \
        --username "${endEntityName}" \
        --password "${keyStorePassword}"

    ejbca_command batch \
        --username "${endEntityName}" \
        -dir ${tempDir}/

    if [ ! -f "${tempDir}/${endEntityName}.jks" ] ; then
        log "WARN" "Unable to issue TLS certificate for local instance using ${CA_NAME}."
    else
        mv "${tempDir}/${endEntityName}.jks" "${keyStoreJks}"
        echo "${keyStorePassword}" > "${keyStoreStorepasswd}"
        java_keytool -exportcert -keystore "${keyStoreJks}" -storepass ${keyStorePassword} \
            -alias "${instanceHostname}" -file ${tempDir}/keystore.der \
            | log "INFO"
        keyStoreCertSha256=$(sha256sum ${tempDir}/keystore.der | awk '{print $1}')
        if [ -f ${tempDir}/keystore.der ] ; then rm ${tempDir}/keystore.der ; fi
        log "INFO" "Generated TLS certificate with fingerprint ${keyStoreCertSha256}."
    fi
fi
