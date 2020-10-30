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

# Allow open system management of EJBCA's Admin GUI if there is no non-CLI SuperAdmin.
existingNonSuperAdminRoles="$(ejbca_command roles listroles | grep -v 'Super Administrator Role')"
if [ "x$existingNonSuperAdminRoles" == "x" ] ; then
  existingNonCliSuperAdmins="$(ejbca_command roles listadmins --role \"Super Administrator Role\" | grep -v 'USERNAME TYPE_EQUALCASE \"ejbca\"')"
  if [ "x$existingNonCliSuperAdmins" == "x" ] ; then
    # There is only the Super Administrator Role present and it only has the EJBCA EJB CLI match configured
    log "INFO" "Adding initial application RoleMember (\"${INITIAL_ADMIN}\")."
    #IFS=';' ; read -ra intialAdminArray <<< "$INITIAL_ADMIN" ; IFS=' '
    intialAdminArray=(); while read -rd\; ; do intialAdminArray+=("$REPLY"); done <<<"${INITIAL_ADMIN};"
    if [ ${#intialAdminArray[@]} -ne 3 ] ; then
        # Default to an open system unless previously configured
        log "WARN" "Environment variable INITIAL_ADMIN (\"${INITIAL_ADMIN}\") is not properly formatted and has ${#intialAdminArray[@]} parts."
        roleMemberCa=""
        roleMemberWith="PublicAccessAuthenticationToken:TRANSPORT_CONFIDENTIAL"
        roleMemberValue=""
    else
        roleMemberCa="${intialAdminArray[0]}"
        roleMemberWith="${intialAdminArray[1]}"
        roleMemberValue="${intialAdminArray[2]}"
    fi

    # Configure a SuperAdmin match for anyone accessing the Admin GUI
    ejbca_command roles addrolemember \
      --namespace "" \
      --role "Super Administrator Role" \
      --caname "$roleMemberCa" \
      --with "$roleMemberWith" \
      --value "$roleMemberValue" \
      --description "Initial RoleMember." || log "ERROR" "Failed to add initial RoleMember."
  fi
fi

existingPublicAccessSuperAdmins="$(ejbca_command roles listadmins --role \"Super Administrator Role\" | grep 'TRANSPORT_.* TYPE_UNUSED')"
configuredInPreviousRun="$(grep 'web.reqcert=false' ${baseDir}/ejbca/conf/web.properties)"
sleepBeforeEnablingHealthCheck=0
if [ "x$existingPublicAccessSuperAdmins" != "x" ] ; then
  # Allow other types of authentication than client TLS certificate for EJBCA Admin GUI management
  if [ "x$configuredInPreviousRun" == "x" ] ; then
    echo "web.reqcert=false" >> ${baseDir}/ejbca/conf/web.properties
    # EJBCA might take up to 5 seconds to detect this configuration change. Ensure that we don't signal ALLOK before this happens.
    sleepBeforeEnablingHealthCheck=1
  fi
else
  if [ "x$configuredInPreviousRun" != "x" ] ; then
    sed -i 's/web.reqcert=.*//' ${baseDir}/ejbca/conf/web.properties
    # EJBCA might take up to 5 seconds to detect this configuration change. Ensure that we don't signal ALLOK before this happens.
    sleepBeforeEnablingHealthCheck=1
  fi
fi

# Show information in relation to this build (once)
if [ -f ${baseDir}/bin/internal/after-deployed.message ] ; then
    if [ "x${SETUP_MESSAGE_DISABLED}" != "xtrue" ] ; then
        cat ${baseDir}/bin/internal/after-deployed.message | log "INFO"
        rm ${baseDir}/bin/internal/after-deployed.message
    fi
fi

# Ensure that health check will report this instance as available now when it is fully started
if [ $sleepBeforeEnablingHealthCheck = 1 ] ; then
    log "INFO" "Waiting 5 seconds before signaling application readiness to ensure proper handling of PublicAccessAuthenticationToken."
    sleep 5
fi
ejbca_health_check_set_not_ready "false"
log "INFO" "Health check now reports application status at /ejbca/publicweb/healthcheck/ejbcahealth"

if [ -f ${tempDir}/enrollment-info.txt ] ; then
    cat ${tempDir}/enrollment-info.txt | log "INFO"
fi
