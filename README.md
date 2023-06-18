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

---

## Задание со *

- Дополнить конфигурацию **Vagrant** для корректной работы проксирования приложения с помощью **nginx**

То есть пользователь набирает на своем браузере адрес **http://192.168.56.20** и нстроенная функция реверс-проксы перенправялет запрос на **http://127.0.0.1:9292**

### И как же я добился этого?
После прочтения десяток статьей в течении более 10 часов, после скитаний между плагинами тима:
- vagrant-reverse-proxy
- vagrant-proxyconf
и еще парочкой других, наконец, решил правильно прочитать условия задачи и обратил внимание на строки "проксирования приложения с помощью **nginx**"

И начал копать настройки **gginx**, а именно содержимое роли **jdauphant.nginx**. Ведь именно эта комюнити роль и создаёт веб-сервер **nginx**
Так вот, копался в содержимом роли **jdauphant.nginx** и наткнулс на дефолтную переменную **nginx_sites** и вспомнил, что именно такую переменную использовал в предидущем ДЗ **ansible-3** для обратного проксирования. В итоге решил скорректировать значения переменной **nginx_sites**:

### было
```bash
nginx_sites:
  default:
    - listen 80 default_server
    - server_name _
    - root "{{ nginx_sites_default_root }}"
    - index index.html
```

### стало
```bash
nginx_sites:
  default:
    - listen 80 default_server
    - server_name _
    - root "{{ nginx_sites_default_root }}"
    - location / { proxy_pass http://127.0.0.1:9292; }
    - index index.html
```
после запустил:
```bash
vagrant reload --provision
```

И обратное проксирование заработало.

---

## Тестирование роли: Установка зависимостей

Для проведения тестирования необходимо установить **Molecule**, **Ansible**, **Testinfra** на локальную машину используя **pip**.  Установку данных модулей буду выполнять в созданной через **virtualenv** среде работы с питоном.
Можно было воспользоваться **pipenv**, но учитывая то, что материалы ДЗ устаревшие года на 4 минимум, решил отказаться от **pipenv** и использовать **virtualenv**. Полезная ссылка [https://docs.python-guide.org/dev/virtualenvs/]
Установка **virtualenv**
```bash
pip install virtualenv
Defaulting to user installation because normal site-packages is not writeable
Requirement already satisfied: virtualenv in ~/.local/lib/python3.10/site-packages (20.23.0)
Requirement already satisfied: distlib<1,>=0.3.6 in ~/.local/lib/python3.10/site-packages (from virtualenv) (0.3.6)
Requirement already satisfied: filelock<4,>=3.11 in ~/.local/lib/python3.10/site-packages (from virtualenv) (3.12.1)
Requirement already satisfied: platformdirs<4,>=3.2 in ~/.local/lib/python3.10/site-packages (from virtualenv) (3.5.3)
```
```bash
virtualenv --version
virtualenv 20.23.0 from ~/.local/lib/python3.10/site-packages/virtualenv/__init__.py
```
Далее, находясь в директории **ansible** создаю директорию для **virtualenv** под название **venv**, которое уже указано в **.gitignore**
```bash
virtualenv venv
created virtual environment CPython3.10.6.final.0-64 in 93ms
  creator CPython3Posix(dest=~/git/russo1982_infra/ansible/venv, clear=False, no_vcs_ignore=False, global=False)
  seeder FromAppData(download=False, pip=bundle, setuptools=bundle, wheel=bundle, via=copy, app_data_dir=~/.local/share/virtualenv)
    added seed packages: pip==23.1.2, setuptools==67.8.0, wheel==0.40.0
  activators BashActivator,CShellActivator,FishActivator,NushellActivator,PowerShellActivator,PythonActivator
```
что дальше? Вот выдержка из "Полезной ссылки"
```bash
To begin using the virtual environment, it needs to be activated:

$ source venv/bin/activate

The name of the current virtual environment will now appear on the left of the prompt (e.g. (venv)Your-Computer:project_folder UserName$) to let you know that it’s active. From now on, any package that you install using pip will be placed in the venv folder, isolated from the global Python installation.
```
Для начало установки **Molecule**, **Ansible**, **Testinfra** на локальную машину используя **pip**. Но для этого надо активировать **venv**
```bash
ls -l venv/bin/activate
-rw-rw-r-- 1 russo russo 2163 июн 18 12:38 venv/bin/activate
```
```bash
source venv/bin/activate
(venv) ➜  ansible git:(ansible-4) ✗
```
Перед началом установки модулей добавлю следующие записи в файл **requirements.txt** в директории **ansible**:
```bash
ansible>=2.4
molecule>=2.6
testinfra>=1.10
python-vagrant>=0.5.15
```
и запускаю **pip install -r requirements.txt**
После проверяю устновленные модули:
```bash
molecule --version
molecule 5.0.1 using python 3.10
    ansible:2.15.0
    delegated:5.0.1 from molecule
```
```bash
ansible --version
ansible 2.10.8
  config file = ~/git/russo1982_infra/ansible/ansible.cfg
  configured module search path = ['~/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.10.6 (main, May 29 2023, 11:10:38) [GCC 11.3.0]
```

### Тестирование db роли

Командой **molecule init** создаю заготовки тестов для роли **db**. Данную команду необходимо запускать в директории с ролью **ansible/roles/db**
```bash
molecule init scenario --role-name db --driver-name vagrant

Error: Invalid value for '--driver-name' / '-d': 'vagrant' is not 'delegated'.
```
Для исправления ошибки устанавливаю модуль **molecule-vagrant**
```bash
pip install molecule-vagrant

Installing collected packages: distro, selinux, molecule-vagrant
Successfully installed distro-1.8.0 molecule-vagrant-2.0.0 selinux-0.3.0
```
И результат команды
```bash
molecule init scenario --role-name db --driver-name vagrant --verifier-name testinfra

INFO     Initializing new scenario default...
INFO     Initialized scenario in ~/git/russo1982_infra/ansible/roles/db/molecule/default successfully.
```

После добавляю несколько тестов, используя модули **Testinfra** для проверки конфигурации, настраиваемой ролью **db**
**db/molecule/default/tests/test_default.py**
```bash
"""Role testing files using testinfra."""

import os

import testinfra.utils.ansible_runner


testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')

def test_hosts_file(host):
    """Validate /etc/hosts file."""
    f = host.file("/etc/hosts")

    assert f.exists
    assert f.user == "root"
    assert f.group == "root"

# check if MongoDB is enabled and running
def test_mongo_running_and_enabled(host):
    mongo = host.service("mongod")
    assert mongo.is_running
    assert mongo.is_enabled

# check if configuration file contains the required line
def test_config_file(host):
    config_file = host.file('/etc/mongod.conf')
    assert config_file.contains('bindIp: 0.0.0.0')
    assert config_file.is_file
```
### Создание тестовой машины

Описание тестовой машины, которая создается **Molecule** для тестов содержится в файле **db/molecule/default/molecule.yml**

```bash
---
dependency:
  name: galaxy
driver:
  name: vagrant
  provider:
    name: virtualbox
lint: yamllint
platforms:
  - name: instance
    box: ubuntu/xenial64
provisioner:
  name: ansible
  lint: ansible-lint
verifier:
  name: testinfra
```

Далее в директории **ansible/roles/db** запускаю команду для создания VM
```bash
molecule create
```
Но, и снова ошибка
```bash
ERROR    Computed fully qualified role name of db does not follow current galaxy requirements.
Please edit meta/main.yml and assure we can correctly determine full role name:

galaxy_info:
role_name: my_name  # if absent directory name hosting role is used instead
namespace: my_galaxy_namespace  # if absent, author is used instead
```
Вношу корректировки в файл **meta/main.yml**
```bash
galaxy_info:
  author: russo
  description: role db used in molecule test
  company: your company (optional)
  role_name: db
  namespace: russo
```
И вот результат. Это список созданных инстансов, которыми управляет **Molecule**
```bash
molecule list

  Instance Name │ Driver Name │ Provisioner Name │ Scenario Name │ Created │ Converged
╶───────────────┼─────────────┼──────────────────┼───────────────┼─────────┼───────────╴
  instance      │ vagrant     │ ansible          │ default       │ true    │ false
```
При необходимости дебага подключиться по SSH внутрь VM
```bash
molecule login -h instance

Last login: Sun Jun 18 18:14:21 2023 from 10.0.2.2
vagrant@instance:~$
```

### playbook.yml

В описании ДЗ указано, что **molecule init** генерирует плейбук для применения нашей роли. Данный плейбук можно посмотреть по пути **db/molecule/default/playbook.yml**.

Снова напомню, что из-за того, то материалы ДЗ устарели лет на четыри у меня файл **playbook.yml** не был создан. Вместо данного файла уже используется файл **converge.yml** в которую просто надо добавить строку **become: true**

**db/molecule/default/converge.yml**
```bash
---
- name: Converge
  hosts: all
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: "Include db"
      ansible.builtin.include_role:
        name: "db"
```
Зпускаю **converge.yml**
```bash
molecule converge

PLAY RECAP *********************************************************************
instance                   : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Перед запуском тестов проверю настройки **mongod** в созданном инстансе
```bash
molecule login -h instance

vagrant@instance:~$ cat /etc/mongod.conf
...

# network interfaces
net:
  port: 27017 # default - один из фильтров Jinja2, он задает значение по умолчанию, если переменная слева не определена
  bindIp: 0.0.0.0
```
```bash
vagrant@instance:~$ sudo systemctl status mongod
● mongod.service - High-performance, schema-free document-oriented database
   Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
   Active: active (running) since Sun 2023-06-18 19:52:10 UTC; 13s ago
```

Теперь можно запустить тест **ansible/molecule/defaults/tests/test_default.py**

```bash
molecule verify

============================= test session starts ==============================
platform linux -- Python 3.10.6, pytest-7.3.2, pluggy-1.0.0
rootdir: /home/russo
plugins: testinfra-8.1.0, testinfra-6.0.0
collected 3 items

molecule/default/tests/test_default.py ...                               [100%]

============================== 3 passed in 2.73s ===============================
INFO     Verifier completed successfully.
```

---

## Самостоятельно
