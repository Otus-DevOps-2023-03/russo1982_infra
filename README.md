# russo1982_infra
---
## ДЗ №13 Ansible (Локальная разработка при помощи Vagrant. Работа с веткой ansible-4)

## ПЛАН
- Локальная разработка при помощи **Vagrant**,  доработка ролей для провижининга в **Vagrant**
- Тестирование ролей при помощи **Molecule** и **Testinfra**
- Переключение сбора образов пакером на использование ролей
- * Подключение **Travis CI** для автоматического прогона тестов


## Локальная разработка при помощи **Vagrant**

До начала данного ДЗ все предидущие ДЗ выполнял в Линукс виртуалке, который был установлен в VirtualBox, а на самом хосте у меня был Windows 10.
Думал всё также продолжить выполнения ДЗ связанного с **Vagrant**. Намеривался использовать возможности **vagrant share --ssh** на строне Windows хосте где устанволен VirtualBox и подклчиться к нему через **vagrant connect** из Линукс виртуалки. Но, решил просто идти по простому пути и установил Ubuntu на хост и туда же VirtualBox.

Далее устанавливаю **Vagrant**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |
\ sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant
```
```bash
vagrant --version
Vagrant 2.3.6
```
Описание характеристик cоздаваемой VM должно содержаться в файле с названием **Vagrantfile**.
Создам ту же инсфраструктуру, которую ранее создавал с помощью **Terraform**, но уже с мопощью **Vagrant**.
Перед началом работы с **Vagrant** добавлю следующие строки в **.gitignore** файл
```bash
# Vagrant & molecule
.vagrant/
*.log
*.pyc
.molecule
.cache
.pytest_cache
```
## Vagrantfile

В директории **ansible** создам файл **Vagrantfile** с определением двух VM
```bash
Vagrant.configure("2") do |config|

    config.vm.provider :virtualbox do |v|
      v.memory = 512
    end

    config.vm.define "dbserver" do |db|
      db.vm.box = "ubuntu/xenial64"
      db.vm.hostname = "dbserver"
      db.vm.network :private_network, ip: "10.10.10.10"
    end

    config.vm.define "appserver" do |app|
      app.vm.box = "ubuntu/xenial64"
      app.vm.hostname = "appserver"
      app.vm.network :private_network, ip: "10.10.10.20"
    end
  end
```
После нахожясь в директории **ansible** надо зпустить следующеу команду
```bash
vagrant up
```
ВАЖНО!!! Если нет указанного бокса (образа VM) на локальной машине, то Vagrant попытается его скачать с Vagrant Cloud - главного хранилища Vagrant боксов, откуда Vagrant скачивает образы по умолчанию.

Исправлю эту ошибку. Для решение просто поменяю IP адреса на приемлемые.
```bash
The IP address configured for the host-only network is not within the
allowed ranges. Please update the address used to be within the allowed
ranges and run the command again.

  Address: 10.10.10.10
  Ranges: 192.168.56.0/21

Valid ranges can be modified in the /etc/vbox/networks.conf file.
```

Проверить, что бокс скачался в локальную машину можно
```bash
vagrant box list
  ubuntu/xenial64 (virtualbox, 20211001.0.0)
```
Также можно проверить статус VM
```bash
vagrant status
  Current machine states:

  dbserver                  running (virtualbox)
  appserver                 running (virtualbox)
```

Далее надо проверить SSH доступ к VM с названием **appserver** и уже там проверю пинг хоста **dbserver** по адресу, который указал в **Vagrantfile**
```bash
vagrant ssh appserver

vagrant@appserver:~$ ping 192.168.56.10
PING 192.168.56.10 (192.168.56.10) 56(84) bytes of data.
64 bytes from 192.168.56.10: icmp_seq=1 ttl=64 time=3.75 ms
```
---

## Доработка ролей

Продолжу работать с **Vagrantfile** для добавления туда провижина
```bash
Vagrant.configure("2") do |config|

    config.vm.provider :virtualbox do |v|
      v.memory = 512
    end

    config.vm.define "dbserver" do |db|
      db.vm.box = "ubuntu/xenial64"
      db.vm.hostname = "dbserver"
      db.vm.network :private_network, ip: "192.168.56.10"

      db.vm.provision "ansible" do |ansible|
        ansible.playbook = "playbooks/site.yml"
        ansible.groups = {
        "db" => ["dbserver"],
        "db:vars" => {"mongo_bind_ip" => "0.0.0.0"}
        }
      end
    end

    config.vm.define "appserver" do |app|
      app.vm.box = "ubuntu/xenial64"
      app.vm.hostname = "appserver"
      app.vm.network :private_network, ip: "192.168.56.20"
    end
  end
```

Провижининг происходит автоматически при запуске новой машины. Если надо применить провижининг на уже запущенной машине, то необходимо использовать команду **provision**. Если надо применить команду для конкретного хоста, то нужно передать его имя в качестве аргумента.
```bash
vagrant provision dbserver
```
