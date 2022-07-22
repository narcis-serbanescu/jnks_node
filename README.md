# jnks_node

# Jenkins SSH based Agent Docker/Podman image    
- RHEL8 based container acting as Jenkins agent, with Ansible, Terraform, Helm, kubectl        

# Description    

The container built from this image is intended to be use on a RHEL7 system that by default does not contain podman-remote package.     
In this case the only option to run a container agent is to use SSH, according to: https://www.jenkins.io/doc/book/using/using-agents/    


This is a base image for Docker/Podman, which includes:    
- Podman      
- JDK and the Jenkins agent executable (agent.jar)     
- Ansible package installed via pip     
- Terraform binary installed from https://www.terraform.io/downloads                      
- Helm    
- Kubectl vSphere        
- etc         



# Usage    
1. Building a container from Dockerfile:    
```
podman build --no-cache --squash-all -t jenkins-ansible-ssh-agent -f Containerfile
```

2. The container can be launched externally and attaches to Jenkins.

```sh
podman run -d --privileged --volume=$(pwd)/ansible:/home/jenkins/ansible -p 2222:22 --name jenkins-ansible-ssh-agent localhost/jenkins-ansible-ssh-agent    
```    

after setting **Remote root directory** to `/home/jenkins`.    


3. Execute ansible-playbook               

```sh
podman exec -u=jenkins -w=/home/jenkins/ansible/ --tty jenkins-ansible-ssh-agent env TERM=xterm ansible-playbook get_facts.yml            
```    


4. As another option, the same container can be also attached from a Jenkins pipeline as well    


