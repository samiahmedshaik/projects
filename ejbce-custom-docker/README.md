Instructions:

1. Run docker-compose up

2. Once all the containers are up, the last console log should be something similar to as shown below. It is absolute necessary to follow this step or else the admin access to ejbca will not be granted  

 
      A fresh installation was detected and a RootCA was created for your initial        
      administaration of the system.                                                     
                                                                                     
      Initial SuperAdmin client certificate enrollment URL (adapt port to your mapping): 
                                                                                     
        URL:      https://pki.pam.com:8443/ejbca/enrol/keystore.jsp
        Username: superadmin                                                             
        Password: oZeP/Lh8QNaMOGXa+O6Jxqj9                                               
                                                                                     
      Once the P12 is downloaded, use "oZeP/Lh8QNaMOGXa+O6Jxqj9" to import it.           


3. Once the cert is enrolled and imported into your local cert store, access admin interface as https://pki.pam.com:8443/ejbca/adminweb/. Note that if the cert is not imported properly you will see an error as shown below 

   Authorization Denied
   Cause : Client certificate required.

4. Select "Certificate Profiles" in the UI and import the zip file certprofiles.zip. Once the import is succesfull, you should see USER profile in the UI. Similarly select "End Entity Profiles" and import the zip file entityprofiles.zip. Once the import is succesfull, you should see USER profile in the UI.  

5. Create a new approval profile with the name "User Cert" by selecting "Approval Profiles". Assign this profile to USER certificate profile. 

6. Edit RootCA under "Certification Authorities" and generate CRL and OCSP URLs under the section "Default CA defined validation data". Make sure that localhost in the URL is replaced by "pki.pam.com".

7. Configure Mail server by accessing https://pki.pam.com:9443/. Create an admin user for Mail server and also configure other users that will make use of PKI. Individual users can access their mail boxes using the link https://pki.pam.com:9443/webmail/ and logging with their credentials. 
