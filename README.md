# russo1982_infra
---
## ДЗ №12 Ansible (Ansible: работа с ролями и окружениями. Работа с веткой ansible-3)

### Создание ролей
Создаю директорию **roles** и запуще в ней команды для создания заготовки ролей для конфигурации приложения и БД
```bash
ansible-galaxy init app
- Role app was created successfully
ansible-galaxy init db
- Role db was created successfully
```
В результате создаются папки **app** и **db** с одниковым контентом
```bash
tree app
app
├── defaults
│   └── main.yml
├── files
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── README.md
├── tasks
│   └── main.yml
├── templates
├── tests
│   ├── inventory
│   └── test.yml
└── vars
    └── main.yml
```

```bash
tree db
db
├── defaults
│   └── main.yml
├── files
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── README.md
├── tasks
│   └── main.yml
├── templates
├── tests
│   ├── inventory
│   └── test.yml
└── vars
    └── main.yml
```

### Роль для базы данных

Теперь для роли конфигурации MongoDB скопирую секцию **tasks** в сценарии плейбука **ansible/db.yml** и вставлю ее в файл в директории **tasks** роли **db**
**ansible/roles/db/tasks/main.yml**
```bash
---
# tasks file for db
- name: Change mongo config file
  template:
    src: mongod_conf.j2
    dest: /etc/mongod.conf
    mode: 0644
  notify: restart mongod
```
Далее в директорию шаблоннов роли **ansble/roles/db/templates** скопирую шаблонизированный конфиг для **MongoDB** из директории **ansible/templates**. Модули **template** и **copy**, которые используются в тасках роли, будут по умолчанию проверять наличие шаблонов и файлов в директориях роли **templates** и **files** соответственно. Поэтому достаточно указать в таске только имя шаблона в качестве источника.

Точно по такой же логике оформляем **handlers**
Содержимое файла **ansble/roles/db/handlers/main.yml**
```bash
---
# handlers file for db
- name: restart mongod
  service: name=mongod state=restarted
```
Также в папку **defaults** перенесем нужные переменные
**ansble/roles/db/defaults/main.yml**
```bash
---
# defaults file for db
mongo_port: 27017
mongo_bind_ip: 0.0.0.0
```

Точно такой же подход будем реализовать для роли **app**.
Скопирую секцию **tasks** в сценарии плейбука **ansible/app.yml** и вставлю ее в файл для тасков роли **app**.

### Использую роли в созданных ранее плейбуках

Удалю определение тасков и хендлеров в плейбуках **ansible/app.yml** и **ansible/db.yml** заменив на вызов роли
```bash
---
- name: Configure App
  hosts: app
  # tags: app-tag
  become: true

  vars:
    db_host: 192.168.10.24

  roles:
    - app
```

```bash
---
- name: Configure MongoDB
  hosts: db
  # tags: db-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0

  roles:
    - db
```

Теперь пересоздам инстансы и запущу плебуки.
```bash
terraform destroy
terraform apply
ansible-playbook site.yml --check
ansible-palybook site.yml
```
Перед проверкой изменить внешние IP адреса инстансов в инвентори файле **ansible/inventory** и переменную **db_host** в плейбуке **app.yml**

Инстансы поднялись и плейбук сработал штатно. Всё норм!

---

## Управление окружением через Ansible

Для управление окружениями **prod** и **stage** Создам директорию **environments** в директории **ansible** для определения настроек окружений. В директории **ansible/environments** создам две директории для окружений **stage** и **prod**.

### Inventory File

Необходимо управлять разными хостами на разных окружениях, соответственно нужен свой инвентори-файл для каждого из окружений. Скопирую инвентори файл **ansible/inventory** в каждую из директорий окружения **environtents/prod** и **environments/stage**.

Теперь, чтобы управлять хостами окружения необходимо явно передавать команде, какой инвентори использовать.
Например, чтобы задеплоить приложение на **prod** окружении:
```bash
ansible-playbook -i environments/prod/inventory.json deploy.yml
```

Не забываю определить окружение по умолчанию для окружения **stage** в файле **ansible.cfg**
```bash
[defaults]
inventory =  ./environments/stage/inventory.json
remote_user = ubuntu
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
nocows = True
```
---

## Переменные групп хостов

Параметризация конфигурации ролей за счет переменных дает возможность изменять настройки конфигурации, задавая нужные значения переменных.
Ansible позволяет задавать переменные для групп хостов, определенных в инвентори файле.

Директория **group_vars**, созданная в директории плейбука или инвентори файла, позволяет создавать файлы (имена, которых должны соответствовать названиям групп в инвентори файле) для определения переменных для группы хостов.
Создам директорию **group_vars** в директориях окружений **environments/prod** и **environments/stage**.

### Конфигурация Stage

Зададим настройки окружения stage, используя групповые
переменные:
-  Создам файлы **stage/group_vars/app** для определения переменных для группы хостов **app**, описанных в инвентори файле **stage/inventory**
-  Скопирую в этот файл переменные, определенные в плейбуке **ansible/app.yml**
-  Надо удалить определение переменных из самого плейбука **ansible/app.yml**

Точно так же можно определить переменные для группы хостов БД на окружении **stage**:
-  Создам файл **stage/group_vars/db** и скопирую в него содержимое переменные из плейбука **ansible/db.yml**
-  Секцию определения переменных из самого плейбука **ansible/db.yml** надо удалить.

Далее надо создать файл с переменными для группы **stage/group_vars/all** с содержимым **env: stage**. Таким образом переменные в этом файле будут доступны всем хостам окружения.

### Конфигурация Prod

Конфигурация окружения **prod** будет идентичной, за исключением переменной **env: prod**, определенной для группы **all**.

---
### Вывод информации об окружении

Для хостов из каждого окружения указал переменную **env**, которая содержит название окружения. Теперь надо настроить вывод информации об окружении, при применении плейбуков. Надо указать переменную **env** по умолчанию в используемых ролях. Для этого редактирую файл **defaults/main.yml** в каждом из окружений.

```bash
---
# defaults file for app
db_host: 127.0.0.1
env: local
```
```bash
---
# defaults file for db
mongo_port: 27017
mongo_bind_ip: 127.0.0.1
env: local
```
Теперь создам таск с помощью модуля **debug** для вывода информации о том, в каком окружении находится конфигурируемый хост.
файл **ansible/roles/app/tasks/main.yml**
```bash
# tasks file for app
- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"
```

файл **ansible/roles/db/tasks/main.yml**
```bash
# tasks file for db
- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"
```
Теперь пора наводить порядок в директории **ansible**.
Перенесу все плейбуки в отдельную директорию согласно **best practices**
В директорию **ansible/playbooks** перенесем все плейбуки. А в директорию **ansible/old** перенесу се, что не относится к текущей конфигурации.

Заодно можно улучшить **ansible.cfg**
```bash
[defaults]
inventory =  ./environments/stage/inventory.json
remote_user = ubuntu
private_key_file = ~/.ssh/appuser

# Отключим проверку SSH Host-keys (поскольку они всегда разные для новых инстансов)
host_key_checking = False

# Отключим создание *.retry-файлов (они нечасто нужны, но мешаются под руками)
retry_files_enabled = False

# Явно укажем расположение ролей (можно задать несколько путей через ; )
roles_path = ./roles
nocows = True

[diff]
# Включим обязательный вывод diff при наличии изменений и вывод 5 строк контекста
always = True
context = 5
```
Перед проверкой пересоздам инстансы.

```bash
ansible-playbook playbooks/site.yml --check
ansible-playbook playbooks/site.yml
```
Результат
```bash
PLAY RECAP ********************************************************************************************************
app-server                 : ok=12   changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
db-server                  : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Проверка Prod окружения

Для проверки настройки **prod** окружения сначала надо удалить инфраструктуру окружения **stage**. Пересоздать инстансы и затем поднять инфраструктуру для **prod** окружения.

```bash
ansible-playbook -i environments/prod/inventory.json playbooks/site.yml --check
ansible-playbook -i environments/prod/inventory.json playbooks/site.yml
```

---

## Работа с Community-ролями

 Буду раотать с порталом **Ansible Galaxy** и с помощью утилиты **ansible-galaxy** и файла **requirements.yml**, но этот файл **requirements.yml** будет отдельным для каждого окружения.
 Хорошей практикой является разделение зависимостей ролей **requirements.yml** по окружениям.

А из **Ansible Galaxy** использую роль **jdauphant.nginx** дл настройки обратного проксирования для приложения с помощью **nginx**.

- Создам файлы **environments/stage/requirements.yml** и **environments/prod/requirements.yml**
- Добавля в них запись вида:
```bash
- src: jdauphant.nginx
  version: v2.21.1
```
- Установлю роль:
```bash
ansible-galaxy install -r environments/stage/requirements.yml
```

- Надо учесть, что комьюнити-роли не стоит коммитить в репозиторий, для этого добавлю в **.gitignore** запись: **jdauphant.nginx**

Для минимальной настройки проксирования необходимо добавить следующие переменные:
```bash
nginx_sites:
default:
- listen 80
- server_name "reddit"
- location / {
    proxy_pass http://127.0.0.1:порт_приложения(9292);
}
```
Переменные добавлю в **stage/group_vars/app** и **prod/group_vars/app**

```bash
db_host: 192.168.10.23
nginx_sites:
  default:
    - listen 80
    - server_name "reddit"
    - location / { proxy_pass http://127.0.0.1:9292; }
```
---

## Самостоятельное задание

- **Добавьте в конфигурацию Terraform открытие 80 порта для инстанса приложения**

Для релизации этой задачи необходимо будет создать **security group**, что позволит управлять трафиком.
Возвращаюсь в прошлое и добиваюсь от модуля **vpc** того, чтоб он "выплюнул мне **id** сети над которым и будем управлять создаваемыё **security group**
Для этого изменения добавлюя в файл **terraform/modules/vpc/outpit.tf**
```bash
output "app-network" {
  value = yandex_vpc_network.app-network.id
}
```
Далее создаю **security group** уже в файле **terraform/stage/main.tf** где обращаюсь к данным **app-network**, которые выплюнул модуль **vpc**
```bash
resource "yandex_vpc_security_group" "web-server" {
  name        = "HTTPD security group"
  description = "Security group to route the trafic into web server"
  network_id  = module.vpc.app-network

  ingress {
    protocol       = "TCP"
    description    = "HTTP trafic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH trafic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "Allow any outoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = -1
    to_port        = -1
  }
}
```

- Добавьте вызов роли **jdauphant.nginx** в плейбук **app.yml**
```bash
  roles:
    - app
    - jdauphant.nginx
```

- Примените плейбук site.yml для окружения stage и проверьте, что приложение теперь доступно на 80 порту
  РАБОТАЕТ!!!

  ---
  ## Работа с Ansible Vault

Надо подготовимть плейбук для создания пользователей, пароль пользователей будет храниться в зашифрованном виде в файле **credentials.yml**:

- Создаётся файл **~/.ansible/vault.key** со произвольной строкой ключа
- Редактирую файл **ansible.cfg**, добавлю опцию
```bash
[defaults]
...
vault_password_file = ~/.ansible/vault.key
```
Обязательно добавьте в **.gitignore** файл **vault.key**

Файл **ansible/playbooks/users.yml** для создания пользователей:
```bash
---
- name: Create users
  hosts: all
  become: true

  vars_files:
    - "{{ inventory_dir }}/credentials.yml"

  tasks:
    - name: create users
      user:
        name: "{{ item.key }}"
        password: "{{ item.value.password|password_hash('sha512', 65534|random(seed=inventory_hostname)|string) }}"
        groups: "{{ item.value.groups | default(omit) }}"
      with_dict: "{{ credentials.users }}"
```

Создадю файл с данными пользователей для каждого окружения

Файл для **prod** (ansible/environments/prod/credentials.yml):
```bash
# prod
credentials:
  users:
    admin:
      password: some-pass
      groups: sudo
```

Файл для **stage** (ansible/environments/stage/credentials.yml):
```bash
# stage
credentials:
  users:
    admin:
      password: some-pass
      groups: sudo
    qauser:
      password: some-pass
```

Запускаю шифрование файлов используя **vault.key** (используем одинаковый для всех окружений):
```bash
ansible-vault encrypt environments/prod/credentials.yml
ansible-vault encrypt environments/stage/credentials.yml
```
Теперь добавлю вызов плейбука в файл **site.yml** и запущу его для **stage** окружения:
```bash
---
- import_playbook: db.yml
- import_playbook: app.yml
- import_playbook: deploy.yml
- import_playbook: users.yml
```
Результат:
```bash
ssh ubuntu@158.160.61.59
Welcome to Ubuntu 16.04.7 LTS (GNU/Linux 4.4.0-142-generic x86_64)

ubuntu@reddit-app:~$ cat /etc/passwd
...
ubuntu:x:1000:1001:Ubuntu:/home/ubuntu:/bin/bash
admin:x:1001:1002::/home/admin:
qauser:x:1002:1003::/home/qauser:
```

---

## Задание с ⭐⭐: Настройка TravisCI

**.travis.yml** файл создан, но проверить его не получилось.
есть вот это решение https://stackoverflow.com/questions/21053657/how-to-run-travis-ci-locally
Но, использовать его, наверное, придётся уже в следующих ДЗ.

А пока ВСЁ!!!
