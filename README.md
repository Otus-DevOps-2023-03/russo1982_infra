# russo1982_infra
---
## ДЗ №10 Ansible (Знакомство с Ansible. Работа с веткой ansible-1)

Создаю новуб ветку **ansible-1** для выполнения данного ДЗ
```bash
git branch ansible-1
git switch ansible-1
```
Далее установлю **python 2.7**. В системе уже есть **python 3**
```bash
➜  ~ python3
Python 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
➜  ~ which python3
/usr/bin/python3
➜  ~
```
но, для выполнения задач необходим именно **python 2.7**. Его и установлю на основе этого **https://linuxconfig.org/install-python-2-on-ubuntu-22-04-jammy-jellyfish-linux**

```bash
sudo apt update
sudo apt install python2
python2 -V
  Python 2.7.18
```

А пакетный менеджер **pip** ранее уже был установлен
```bash
pip --version
  pip 22.0.2 from /usr/lib/python3/dist-packages/pip (python 3.10)
```

Создайм в корне инфраструктурного репозитория директорию **ansible** . Вся дальнейшая работа с Ansible будет производится в ней
Созадаю файл **requirements.txt** и после устанавливаю **ansible**
```bash
echo "ansible>=2.4" > requirements.txt
cat requirements.txt
  ansible>=2.4

pip install -r requirements.txt
  Successfully installed ansible-7.5.0 ansible-core-2.14.5 jinja2-3.1.2 packaging-23.1 resolvelib-0.8.1

ansible --version
  ansible [core 2.14.5]
    config file = None
    configured module search path = ['/home/std/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
    ansible python module location = /home/std/.local/lib/python3.10/site-packages/ansible
    ansible collection location = /home/std/.ansible/collections:/usr/share/ansible/collections
    executable location = /home/std/.local/bin/ansible
    python version = 3.10.6 (main, Mar 10 2023, 10:55:28) [GCC 11.3.0] (/usr/bin/python3)
    jinja version = 3.1.2
    libyaml = True
  ```
Меня тут, конечно, смущает, что указана версия **python version = 3.10.6** но, если далее будет проблемы смогу поменять настройки в **ansible**

---

### Запуск VMs

1. Создаю инстансы описанные в **stage**?, но с установкой **Python >=2.7**
```bash
sudo apt-get install -y python
```
Тут следует напумнить, что образы мы испоьзуем те, которые создал Packer

2. После как инстансы созданы необходимо создать файл **inventory** где опишу какими хостами будет управлять Ansible
**inventory**
```bash
appserver ansible_host=<xxx.xxx.xxx.xxx> ansible_user=appuser ansible_private_key_file=~/.ssh/some-key
```
Проверяем есть ли теперь доступ у Ansible к хостам
```bash
 ansible appserver -i ./inventory -m ping
```
и вот результат
```bash
pp-server | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
```
Настораживает строка **"discovered_interpreter_python": "/usr/bin/python3"**, но пока оставлю так.

Продолжим...

Создаю файл конфигураций **ansible.cfg** для Ansible
```bash
[defaults]
inventory = ./inventory
remote_user = <some-user>
private_key_file = ~/.ssh/some-key
host_key_checking = False
retry_files_enabled = False
```
После этого можно удалить лишные данные из файла **inventory**

Используем модуль **command** , который позволяет запускать произвольные команды на удаленном хосте. Выполним команду **uptime** для проверки времени работы инстанса. Команду передадим как аргумент для данного модуля, использовав опцию **-a** :

```bash
ansible db-server -m command -a uptime

  db-server | CHANGED | rc=0 >>
  08:46:52 up 13 min,  1 user,  load average: 0.00, 0.00, 0.00

ansible app-server -m command -a uptime

  app-server | CHANGED | rc=0 >>
  08:47:01 up 11 min,  1 user,  load average: 0.00, 0.07, 0.08
```
Далее изменю инвентори файл следующим образом, чтоб создать группу хостов:
```bash
[app] # Это название группы
app-server ansible_host=xxx.xxx.xxx.xxx  # Cписок хостов в данной группе

[db0] # Это название группы
db-server ansible_host=xxx.xxx.xxx.xxx # Cписок хостов в данной группе
```
И теперь мы можно управлять не отдельными хостами, а целыми группами, ссылаясь на имя группы:
```bash
ansible app -m ping
  app-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }

ansible db -m ping
  db-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }
```
Работает! Но, теперь создам файл **inventory.yml** и перенесу в него записи из имеющегося inventory.
```bash
all:
  children:
    app:
      hosts:
        app-server:
          ansible_host: xxx.xxx.xxx.xxx
    db:
      hosts:
        db-server:
          ansible_host: xxx.xxx.xxx.xxx
```
И вот результат
```bash
ansible all -m ping -i inventory.yml
  db-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }
  app-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }
```
Теперь попробую не заходя на хосты, проверить наличие **ruby** в одном, и **mongod** в другом.

```bash
ansible app -m command -a 'ruby -v'
  app-server | CHANGED | rc=0 >>
  ruby 2.3.1p112 (2016-04-26) [x86_64-linux-gnu]


ansible app -m command -a 'bundler -v'
  app-server | CHANGED | rc=0 >>
  Bundler version 1.11.2
```
**ruby** и **bundler** устанволены и работают. Но, используя модуль **command** нет возможности указать запуск сразу комманд **ruby -v** и **bundler -v**

Для этого необхожимо использовать модуль **shell**
```bash
ansible app -m shell -a 'ruby -v; bundler -v'
  app-server | CHANGED | rc=0 >>
  ruby 2.3.1p112 (2016-04-26) [x86_64-linux-gnu]
  Bundler version 1.11.2
```
Провер. на хосте с БД статус сервиса MongoDB
```bash
ansible db -m shell -a 'systemctl status mongod'
  db-server | CHANGED | rc=0 >>
  ● mongod.service - High-performance, schema-free document-oriented database
     Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
    Active: active (running) since Fri 2023-05-19 08:34:21 UTC; 4h 17min ago
```
Можно выполнить ту же операцию используя модуль **systemd**
```bash
ansible db -m systemd -a name=mongod
```
или еще лучше с помощью модуля **service** , который более универсален и будет работать и в более старых ОС с init.d-инициализацией
```bash
ansible db -m service -a name=mongod
```

Далее поработаю с PLAYBOOK и запущу YAML файл **clone.yml**
и следующий результат после заупска:
```bash
ansible-playbook clone.yml
  PLAY [Clone] *********

  TASK [Gathering Facts] ***********
  ok: [app-server]

  TASK [Clone repo] *************
  ok: [app-server]

  PLAY RECAP ********************************************************************************************************
  pp-server                 : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Проверю что унтри директории **reddit**
```bash
ansible app -m shell -a 'ls /home/ubuntu/reddit'
  app-server | CHANGED | rc=0 >>
  Capfile
  Gemfile
  Gemfile.lock
  README.md
  app.rb
  config
  config.ru
  helpers.rb
  views
```
После удалю директорию **reddit**
```bash
ansible app -m command -a 'rm -rf ~/reddit'
  app-server | CHANGED | rc=0 >>


ansible app -m shell -a 'ls /home/ubuntu/'
  app-server | CHANGED | rc=0 >>

```
Директория **reddit** удалена.
Запускаю плейбук **clone.yml** снова
```bash
ansible-playbook clone.yml
...
TASK [Clone repo] ************
changed: [app-server]

PLAY RECAP *********************************************************************************************************
app-server                 : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0


ansible app -m shell -a 'ls /home/ubuntu/reddit/'
  app-server | CHANGED | rc=0 >>
  Capfile
  Gemfile
  Gemfile.lock
  README.md
  app.rb
  config
  config.ru
  helpers.rb
  views
```
Как видно по результату, после удаления и запуска плейбука повторно указывается что **changed=1** и в тоже время общий результат произведённых действий **ok=2**, что означает нисмотря на удаление директории и запуска плейбка повторно результат получен одинаковый. Таким образом еще раз убедиться можно в том, что идемпотентность сохранилась.

---

### Задание со ⭐

Необходимо добиться генерации динамического файла **inventory.json**. После долгих скитаний по интернету решил просто ипользовать уже готовый ресурс Terraform
```bash
resource "local_file"
```
Данный блок расположил в файле **main.tf** в **stage**
```bash
resource "local_file" "app_inventory" {
  filename = "../../ansible/inventory.json"
  content  = <<-EOF
  {
  "all": {
    "children": {
      "app": {
        "hosts": {
          "app-server": {
            "ansible_host": ${module.app.external_ip_address_app}
          }
        }
      },
      "db": {
        "hosts": {
          "db-server": {
            "ansible_host": ${module.db.external_ip_address_db}
          }
        }
      }
    }
  }
}

EOF
}
```

После запуска **terraform apply** проверяем
```bash
ansible all -m ping -i inventory.json
  app-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }
  db-server | SUCCESS => {
      "ansible_facts": {
          "discovered_interpreter_python": "/usr/bin/python3"
      },
      "changed": false,
      "ping": "pong"
  }
```
После внёс изменения в файл **ansible.cfg**
```bash
[defaults]
inventory = ./inventory.json
remote_user = ubuntu
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```
Тут стоить указать что, в файле **inventory.json** динамическим является только указание IP адресов инстансов, но есть возможность получить еще больше данных из инстанса и указать в файле чтоб полностью добиться динамического свойства.

ВСЁ!!!
---
