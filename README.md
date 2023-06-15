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
Выдаёт ошибку связанную с **mongod**
```bash
RUNNING HANDLER [db : restart mongod] ******************************************
fatal: [dbserver]: FAILED! => {"changed": false, "msg": "Could not find the requested service mongod: host"}
```
Установка MongoDB производилась в отдельном плейбуке **packer_db.yml**, который использовался в качестве провижинера в Packer. Включу этот плейбук в роль **db**, чтоб управлять всем жизненным циклом БД, включая ее установку.

В директории **ansible/roles/db/** создам файл **install_mongo.yml**
```bash
---
- name: Import the public key used by the package management system
  apt_key:
    keyserver: hkp://keyserver.ubuntu.com:80
    id: d68fa50fea312927
  tags: install

- name: Add MongoDB repository
  apt_repository:
    repo: "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse"
    state: present
  tags: install

- name: "apt-get update"
  apt: update_cache=yes
  tags: install

- name: install Mongodb-3.2
  apt:
    name: mongodb-org
    state: present
  tags: install

- name: Configure service supervisor
  systemd:
    name: mongod
    enabled: yes
  tags: install
```
Заметно, что в каждом таксе есть тэг **install**.
Роли начинают включать в себя все больше тасков, поэтому надо группировать их по разным файлам. Уже вынес таски установки MongoDB в отдельный файл роли, аналогично надо сделать для тасков управления конфигурацией.
Таски управления конфигом монги тоже вынесу в отдельный файл **config_mongo.yml**
```bash
---
- name: Change mongo config file
  template:
    src: mongod_conf.j2
    dest: /etc/mongod.conf
    mode: 0644
  notify: restart mongod
```
Теперь уже в файле роли **taks/main.yml**  буду вызывать таски внужном нам порядке
```bash
---
# tasks file for db
- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"

- include: install_mongo.yml
- include: config_mongo.yml
```
Можно применить роль для локальной машины **dbserver**
```bash
vagrant provision dbserver
```
Очень странная проблема тут возникла с "чедсной переменной" **{{ invemroty_dir }}**
Vagrant игрорирует перменную и вадёт ошибку, что не может найти файл **credentials.yml**
Решение такое:
В файле **users.yml** вместо
```bash
vars_files:
    - "{{ inventory_dir }}/credentials.yml"
```
указываю
```bash
vars_files:
    - "/home/russo/git/russo1982_infra/ansible/environments/stage/credentials.yml"
```
Далее проверка прошла успешно.
```bash
vagrant ssh appserver

vagrant@appserver:~$ telnet 192.168.56.10 27017
Trying 192.168.56.10...
Connected to 192.168.56.10.
Escape character is '^]'.
```
Подключение удалось, значит порт доступен для хоста **appserver** и конфигурация роли верна.

Далее необходимую конфигурацию для настройки хоста приложения **appserver** можем взять из плейбука **packer_app.yml**
Создам новый файл для тасков **ruby.yml** внутри роли **app** и скопирую в него таски из плейбука **packer_app.yml**
```bash
---
- name: Install ruby and rubygems and required packages
  apt: "name={{ item }} state=present"
  with_items:
    - ruby-full
    - ruby-bundler
    - build-essential
  tags: ruby
```
Стоит отметить, что ранее в плейбуке **packer_app.yml** я применял минутные паузе перед установкой очередного пакета приложений, так как возникали проблемы связаные с **lock file**. Надеюсь тут такого не будет.

Настройки **puma сервера** также вынесу в отдельный файл для тасков в рамках роли. Создам файл **app/tasks/puma.yml** и скопируем в него таски из **app/tasks/main.yml**, относящиеся к настройке **Puma сервера** и запуску приложения.
```bash
---
- name: Add unit file for Puma
  copy:
    src: puma.service
    dest: /etc/systemd/system/puma.service
  notify:
    - reload systemd
    - reload puma

- name: Add config for DB connection
  template:
    src: db_config.j2
    dest: /home/ubuntu/db_config
    owner: ubuntu
    group: ubuntu

- name: enable puma
  systemd: name=puma enabled=yes
```
В файле **main.yml** роли буду вызывать таски в нужном порядке:
```bash
---
# tasks file for app
- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"

- include: ruby.yml
- include: puma.yml
```
 Далее надо определим Ansible провижинер для хоста **appserver** в **Vagrantfile**
 ```bash
# В директории ansible создайте файл Vagrantfile с определением двух VM

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

      app.vm.provision "ansible" do |ansible|
        ansible.playbook = "playbooks/site.yml"
        ansible.groups = {
        "app" => ["appserver"],
        "app:vars" => { "db_host" => "192.168.56.10"}
        }
      end
    end
  end
 ```

Далее запускаем всё это
```bash
vagrant provision appserver
```
Но выдаёт следующую ошибку:
```bash
TASK [app : Install ruby-full] *************************************************
fatal: [appserver]: FAILED! => {"changed": false, "msg": "No package matching 'ruby-full' is available"}
```
ТОВАРИЩИ!!! ДЕЛАЙТЕ **sudo apt update**

Но, вот не нравиться мне вот это сообщение во время усиановки **bundle**
```bash
TASK [bundle install] **********************************************************
fatal: [appserver]: FAILED! => {"changed": false, "cmd": "/usr/bin/bundle install", "msg": "", "rc": -9, "stderr": "", "stderr_lines": [], "stdout": "Don't run Bundler as root. Bundler can ask for sudo if it is needed, and\ninstalling your bundle as root will break this application for all non-root\nusers on this machine.\nWarning: the running version of Bundler is older than the version that created the lockfile.
```
увидив **lockfile** решил задать паузе после усановки **git** и перед установкой **bundle** в файле **ansible/playbooks/deploy.yml**
```bash
- name: Pause for 1 minutes befor installing bundle
      ansible.builtin.pause:
        minutes: 1
```

Напомню, что **deploy.yml** запускается внутри плейбука **site.yml**, который указан в **Vagrantfile**

В результаты внедрение паузы ничего не изменилось, но вникнув еще глубже прочёл вот это сообщение
```bash
"Don't run Bundler as root. Bundler can ask for sudo if it is needed, and\ninstalling your bundle as root will break this application for all non-root\nusers on this machine.
```
Уберу строку паузы и попробую установить **bundle** из под обычного пользователя
```bash
- name: bundle install
  become: false
  bundler:
    state: present
    chdir: /home/ubuntu/reddit
```
Установка прошла норм. Ругается на устаредость версии, но это не помешает думаю.

### Параметризации роли

В роли **app** были захардкодины пути установки конфигов и деплоя приложения в домашнюю директорию пользователя **ubuntu**. Параметризую имя пользователя, чтобы дать возможность использовать роль для иного пользователя. Определю переменную по умолчанию внутри роли в файле **app/defaults/main.yml**
```bash
# defaults file for app
db_host: 127.0.0.1
env: local
deploy_user: ubuntu
```
Далее зменяю модуль для копирования **unit** файла с **copy** на **template** в файле **app/tasks/puma.yml**, чтобы иметь возможность параметризировать **unit** файл:
При этом надо переместить файл **puma.service** из директории **app/files** в директорию **app/templates** и переименовать на **puma_service.j2**
Теперь можно параметрезировать сам файл **puma_service.j2**
```bash
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
EnvironmentFile=/home/{{ deploy_user }}/db_config
User={{ deploy_user }}
WorkingDirectory=/home/{{ deploy_user }}/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always

[Install]
WantedBy=multi-user.target
```
В файле **app/tasks/puma.yml** параметризую оставшуюся конфигурацию
```bash
---
- name: Add unit file for Puma
  template:
    src: puma_service.j2
    dest: /etc/systemd/system/puma.service
  notify:
    - reload systemd
    - reload puma

- name: Add config for DB connection
  template:
    src: db_config.j2
    dest: "/home/{{ deploy_user }}/db_config"
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"

- name: enable puma
  systemd: name=puma enabled=yes
```

Параметризация файла **deploy.yml**
```bash
- name: Deploy App
  hosts: app
  # tags: deploy-tag
  become: true
  tasks:
    - name: Install git
      apt:
        name: git
        state: present
        update_cache: yes

    - name: Fetch the latest version of application code
      git:
        repo: "https://github.com/express42/reddit.git"
        dest: "/home/{{ deploy_user }}/reddit"
        version: monolith
      notify: restart puma

    - name: bundle install
      become: false
      bundler:
        state: present
        chdir: "/home/{{ deploy_user }}/reddit"

  handlers:
    - name: restart puma
      become: true
      systemd: name=puma state=restarted
```

Теперь при вызове плейбуков для **appserver** надо переопределим дефолтное значение переменной пользователя на имя пользователя используемое нашим боксом по умолчанию, т.е. **ubuntu**. Используем при этом переменные **extra_vars** внутри **Vagrantfile**, имеющие самый высокий приоритет по сравнению со всеми остальными.
Другими словами - благодаря **extra_vars** можно находясь внутри **Vagrantfile** дотянуться до файла деволтных переменных в роли **app/defaults/mail.yml**, где и указана перменная под названием **deploy_user: ubuntu** и ее значение.
Так вот с помощью **extra_vars** внутри **Vagrantfile** можно поменять значение:
```bash
ansible.extra_vars = {
"deploy_user" => "ubuntu"
}
```
ПРОВЕРЯЕМ заново запустив
``bash
vagrant provision appserver
```
При запуске выдаёт ошибку
```bash
We suggest you upgrade to the latest version of Bundler by running gem install bundler
```
В действительности это Warning, но этого достаточно, чтоб в ***appserver** puma.service не поднялся.
Причину проблемы искал двое суток. Пришёл к решению, что надо просто в **Vagrantfile** изменить свойства поднимаемых машин
```bash
config.vm.provider :virtualbox do |v|
      v.memory = 2048
      v.cpus = 2
    end
```
И всё заработало.
