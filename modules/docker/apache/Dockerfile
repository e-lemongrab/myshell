#FROM rancher-sic-local.$domain_stg_ba:8090/bcnact/tomcat/8-jdk8
FROM debian:buster-slim
EXPOSE 80
#EXPOSE 443
###########             SISTEMA
RUN apt update
RUN apt install nano dos2unix unzip apache2 -y
###########             COPIES
COPY /php/ /tmp/php
COPY entrypoint.bash /
#COPY /prestashop/* /tmp/
#COPY web-dump/* /tmp/
###########             SSL
#COPY /ssl/ /tmp/ssl
#COPY /servername/ /tmp/servername
#RUN sh /tmp/servername/servername.bash
#RUN sh /tmp/ssl/ssl.bash
###########             RUNS
RUN dos2unix /tmp/*
RUN sh /tmp/php/php.bash
RUN rm -rf /var/www/html/*
COPY /images/ /var/www/html/images
#RUN curl --insecure -o vtigercrm.tar.gz -SL https://sourceforge.net/projects/vtigercrm/files/vtiger%20CRM%207.0.1/Core%20Product/vtigercrm7.0.1.tar.gz \
#    && tar -xzf vtigercrm.tar.gz \
#    && rm vtigercrm.tar.gz \
#    && chmod -R 775 vtigercrm \
#    && chown -R www-data:www-data vtigercrm
#RUN echo "Donant permisos www-data a directoris"
#RUN chown -R www-data:www-data /etc/apache2/
#RUN chown -R www-data:www-data /var/www/html/
#RUN chmod -R 755 /var/www/html/
ENTRYPOINT ["/entrypoint.bash"]