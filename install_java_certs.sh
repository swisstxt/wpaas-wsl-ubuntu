
for cert in $(ls certificates/*.crt); do
    echo "adding $cert to java keystore"
    sudo keytool -importcert -file $cert -alias $cert -cacerts -storepass changeit -noprompt
done

