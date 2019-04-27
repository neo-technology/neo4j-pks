FROM launcher.gcr.io/google/debian9
LABEL Maintainer="David Allen <david.allen@neo4j.com>"
RUN apt-get update
RUN apt-get install -y bash curl wget gnupg apt-transport-https curl apt-utils
RUN wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
RUN echo 'deb https://debian.neo4j.org/repo stable/' | tee -a /etc/apt/sources.list.d/neo4j.list
RUN apt-get update && apt-get -y upgrade 
RUN apt-get install -y cypher-shell

CMD ["/bin/bash"]
