FROM docker.elastic.co/elasticsearch/elasticsearch:7.1.1

#### You can add NLA plugins listed in https://www.elastic.co/guide/en/elasticsearch/plugins/7.1/analysis.html ####
RUN \
  elasticsearch-plugin install --batch analysis-icu && \
  elasticsearch-plugin install --batch analysis-kuromoji

#### If you build a cluster with multiple data nodes, you need to specify certificate files. ####
# RUN mkdir /usr/share/elasticsearch/config/certs
# ADD elastic-certificates.p12 /usr/share/elasticsearch/config/certs/elastic-certificates.p12
# ADD elastic-stack-ca.p12 /usr/share/elasticsearch/config/certs/elastic-stack-ca.p12
# RUN chown -R elasticsearch /usr/share/elasticsearch/config/certs
# RUN chgrp -R root /usr/share/elasticsearch/config/certs
# RUN chmod o-rx /usr/share/elasticsearch/config/certs
# RUN chmod 640 /usr/share/elasticsearch/config/certs/elastic-stack-ca.p12
# RUN chmod 640 /usr/share/elasticsearch/config/certs/elastic-certificates.p12
