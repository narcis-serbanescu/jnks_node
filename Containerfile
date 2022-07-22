# Get RHEL83 - Red Hat Universal Base Image
FROM registry.access.redhat.com/ubi8/ubi:8.3

ENV container=docker

ARG VERSION=4.13
ARG user=jenkins
ARG group=jenkins
ARG AGENT_WORKDIR=/home/${user}/agent

ENV pip_packages "ansible"

LABEL \
    org.opencontainers.image.vendor="DevSecOps" \
    org.opencontainers.image.title="Jenkins Agent Base Docker image" \
    org.opencontainers.image.description="This is a base image, which provides Ansible, Terraform, Helm, kubectl binaries" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.url="https://www.jenkins.io/" \
    org.opencontainers.image.source="https://github.ibm.com/narcis-serbanescu/containers/tree/main/jenkins_ssh_ansible_terraform_rhel8" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.authors="narcis_serbanescu@ro.ibm.com"

# Install dependencies
RUN yum --disableplugin=subscription-manager -y update \
  && yum --disableplugin=subscription-manager -y module enable python38:3.8 \
  && yum --disableplugin=subscription-manager -y module install python38 \
  && yum --disableplugin=subscription-manager -y install bind-utils curl git fontconfig iproute iputils java-1.8.0-openjdk java-1.8.0-openjdk-devel net-tools openssh-server openssh-clients podman podman-remote yum-utils unzip \
  && yum --disableplugin=subscription-manager clean all

# Install terraform via yum https://www.terraform.io/cli/install/yum
#RUN yum-config-manager --disableplugin=subscription-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#RUN yum --disableplugin=subscription-manager -y install terraform \
#  && yum --disableplugin=subscription-manager clean all

# setup SSH server - https://github.com/jenkinsci/docker-ssh-agent/blob/master/8/bullseye/Dockerfile
RUN sed -i /etc/ssh/sshd_config \
        -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
        -e 's/#RSAAuthentication.*/RSAAuthentication yes/'  \
#        -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/#SyslogFacility.*/SyslogFacility AUTH/' \
        -e 's/#LogLevel.*/LogLevel INFO/' 
RUN mkdir /var/run/sshd &&\
    touch /var/log/secure

RUN /usr/bin/ssh-keygen -A &&\
    chmod 0600 /etc/ssh/ssh_host*

# Install agent #
RUN curl -k --create-dirs -fsSLo /usr/share/jenkins/agent.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/agent.jar \
  && ln -sf /usr/share/jenkins/agent.jar /usr/share/jenkins/slave.jar \
  && yum --disableplugin=subscription-manager clean all

# Adding users and ssh keys
RUN groupadd ${group} \
  && useradd -c "Jenkins user" -g ${group} -G wheel -d /home/${user} -m ${user} \
  && echo jenkins | passwd --stdin ${user} \
  && mkdir /home/jenkins/{.ssh,.jenkins,agent} 


# Create jenkins' own ssh_keys
RUN ssh-keygen -q -N '' -f /home/jenkins/.ssh/id_rsa


# Overrides SSH Hosts Checking
RUN echo "host *" >> /home/jenkins/.ssh/config &&\
    echo "StrictHostKeyChecking no" >> /home/jenkins/.ssh/config &&\
    echo "IdentityFile ~/.ssh/id_rsa" >> /home/jenkins/.ssh/config &&\
    echo "IdentityFile ~/.ssh/id_rsa_avae360" >> /home/jenkins/.ssh/config &&\
    echo "IdentityFile ~/.ssh/id_rsa_avag360" >> /home/jenkins/.ssh/config &&\
    echo "IdentityFile ~/.ssh/id_rsa_avag360" >> /home/jenkins/.ssh/config 

RUN chmod 0600 /home/jenkins/.ssh/id_rsa* &&\
    chown -R jenkins:jenkins /home/jenkins/.ssh/

# Makes dir for Ansible projects
RUN mkdir -p /home/jenkins/ansible &&\
    chown -R jenkins:jenkins /home/jenkins/

# Install Ansible via Pip.
RUN python3 -m pip install --upgrade pip &&\
    pip3 install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org $pip_packages

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible &&\
    echo -e '[local]\nlocalhost ansible_connection=local' > /etc/ansible/hosts

# Install terraform 
WORKDIR /usr/local/bin/
RUN curl -kLO https://releases.hashicorp.com/terraform/1.2.1/terraform_1.2.1_linux_amd64.zip \
  && gzip -S .zip -d terraform_1.2.1_linux_amd64.zip \
  && mv terraform_1.2.1_linux_amd64 /usr/local/bin/terraform \
  && chmod +x /usr/local/bin/terraform


# Install helm
RUN curl -kLO https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz \
  && tar xzf helm-v3.8.2-linux-amd64.tar.gz \
  && mv linux-amd64/helm /usr/local/bin/ \
  && rm -rfv linux-amd64 helm-v3.8.2-linux-amd64.tar.gz

# Over rides SSH Hosts Checking
WORKDIR /root/
RUN mkdir -p /root/.ssh &&\
    echo "host *" >> ~/.ssh/config &&\
    echo "StrictHostKeyChecking no" >> ~/.ssh/config


VOLUME ["/sys/fs/cgroup", "/tmp", "/run", "/ansible"]

# Standard SSH port
EXPOSE 22

# CMD ["/usr/sbin/init"]
CMD ["/usr/sbin/sshd", "-D", "-o", "ListenAddress=0.0.0.0", "-E", "/var/log/secure"]

