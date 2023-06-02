# russo1982_infra
---
## ДЗ №11 Ansible (Деплой и управление конфигурацией с Ansible. Работа с веткой ansible-2)

### Один playbook, один сценарий

Создаю файл **reddit_app.yml** для первого плейбука и также, добавлю в **.gitignore** временные файлы Ansible ***.retry**, чтоб лишнее не отправлять в Git.
**reddit_app.yml**
```bash
---
- name: Configure hosts & deploy application
  hosts: all
  vars:
    mongo_bind_ip: 0.0.0.0 # <-- Переменная задается в блоке vars
  tasks:
    - name: Change mongo config file
      become: true # <-- Выполнить задание от root
      template:
        src: templates/mongod_conf.j2 # <-- Путь до локального файла-шаблона
        dest: /etc/mongod.conf # <-- Путь на удаленном хосте
        mode: 0644 # <-- Права на файл, которые нужно установить
      tags: db-tag # <-- Список тэгов для задачи
```
 Пересоздаю файл inventory.json так как ранее интансы я отключал и запускаю проверку плейбука
 ```bash
ansible-playbook reddit_app.yml --check --limit db
 ```

В результате плейбук готов к применению.

#### Handlers

Нужно определить **handler** для рестарта БД и добавить вызов **handler-а** в созданный таск.
Редактирую файл **reddit_app.yml** и добавляю **handler**
```bash
...
      tags: db-tag # <-- Список тэгов для задачи
      notify: restart mongod
  handlers: # <-- Добавим блок handlers и задачу
    - name: restart mongod
      become: true
      service: name=mongod state=restarted
```
и снова проверяем правильность плейбука

```bash
ansible-playbook reddit_app.yml --check --limit db

PLAY [Configure hosts & deploy application] ************************************************

TASK [Gathering Facts] ************************************************
ok: [db-server]

TASK [Change mongo config file] ************************************************************
changed: [db-server]

RUNNING HANDLER [restart mongod] *************************************************
changed: [db-server]

PLAY RECAP ********************************************
db-server                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Всё норм и теперь боевой запуск плейбука

---


## Настройка инстанса приложения

```bash
mkdir ansible/files
touch files/puma.service
```
Unit file
```bash
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
EnvironmentFile=/home/ubuntu/db_config
User=ubuntu
WorkingDirectory=/home/ubuntu/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always

[Install]
WantedBy=multi-user.target
```
Добавлю в сценарий таск для копирования unit-файла на хост приложения. Для копирования простого файла на удаленный хост, использую модуль **copy** , а для настройки автостарта **Puma-сервера** используем модуль **systemd**
Также укажу новый **handler**, который укажет **systemd**, что **unit** для сервиса изменился и его следует перечитать

```bash
tasks:
 - name: Change mongo config file
...
 tasks:
    - name: Change mongo config file
      become: true # <-- Выполнить задание от root
      template:
        src: templates/mongod_conf.j2 # <-- Путь до локального файла-шаблона
        dest: /etc/mongod.conf # <-- Путь на удаленном хосте
        mode: 0644 # <-- Права на файл, которые нужно установить
      tags: db-tag # <-- Список тэгов для задачи
      notify: restart mongod

    - name: Add unit file for Puma
      become: true
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      tags: app-tag
      notify: reload puma

    - name: enable puma
      become: true
      systemd: name=puma enabled=yes
      tags: app-tag

  handlers: # <-- Добавим блок handlers и задачу
    - name: restart mongod
      become: true
      service: name=mongod state=restarted

    - name: reload puma
      become: true
      systemd: name=puma state=restarted
```
Надо заметить что unit-файл для вебсервера изменился, а там была переменная которая указывала по какому IP идти к БД.
Теперь данную переменную указываю в файле **/home/ubuntu/db_config** , что указано в unit-файле тоже
```bash
EnvironmentFile=/home/ubuntu/db_config
```
Еще раз, через переменную окружения буду передавать адрес инстанса БД, чтобы приложение знало, куда ему обращаться для хранения данных.

Шаблон в директории templates/db_config.j2 содержит присвоение переменной DATABASE_URL значения, которое мы передаем через Ansible переменную **db_host**
```bash
DATABASE_URL={{ db_host }}
```
Редактирую плейбук и добавлю таск для копирования созданного шаблона
```bash
...
task
  - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/ubuntu/db_config
      tags: app-tag
```
После этого **terraform show** и укажу значение пременной **db_host** и снова в самом плейбуке
```bash
db_host: 192.168.10.28
```
И запускаю пробний тест и после боевой если всё норм
```bash
ansible-playbook reddit_app.yml --check --limit app --tags app-tag
```
---

## Деплой

Для практики добавлю еще несколько тасков в сценарий плейбука. Использую модули **git** и **bundle** для клонирования последней версии кода приложения и установки зависимых **Ruby Gems** через **bundle**.
```bash
    - name: Fetch the latest version of application code # <-- Деплой/обновление
      git:
        repo: "https://github.com/express42/reddit.git"
        dest: /home/ubuntu/reddit
        version: monolith # <-- Указываем нужную ветку
      tags: deploy-tag
      notify: reload puma

    - name: Bundle install
      bundler:
        state: present
        chdir: /home/ubuntu/reddit # <-- В какой директории выполнить команд bundle
      tags: deploy-tag
```
Сразу чек и в бой
```bash
ansible-playbook reddit_app.yml --check --limit app --tags deploy-tag
ansible-playbook reddit_app.yml --limit app --tags deploy-tag
```
РАБОТАЕТ!!!

---

## Один плейбук, несколько сценариев

В предыдущей части создал один плейбук, в котором определил один сценарий (play) и для запуска нужных тасков на заданной группе хостов использовал опцию --limit для указания группы хостов и --tags для указания нужных тасков.
Теперь же попробую разбить сценарий на несколько плейбуки.

### Сценарий для MongoDB

Создам новый файл **reddit_app2.yml**. Определю в нем несколько сценариев (plays), в которые объединю задачи, относящиеся к используемым в плейбуке тегам. Отдельный сценарий для управления конфигурацией MongoDB.
Скопирую определение сценария из **reddit_app.yml** и всю информацию, относящуюся к настройке MongoDB, которая будет включать в себя таски, хендлеры и переменные.
Таски требуют выполнения из-под пользователя root , поэтому нет смысла их указывать для каждого task. Укажу **become: true** на уровень сценария.

```bash
---
- name: Configure MongoDB
  hosts: db
  tags: db-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      template:
        src: templates/mongod_conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      notify: restart mongod

  handlers:
    - name: restart mongod
      service: name=mongod state=restarted
```

### Сценарий для App

Скопирую еще раз определение сценария из **reddit_app.yml** и всю информацию относящуюся к настройке инстанса приложения, которая будет включать в себя таски хендлеры и переменные. Вставлю скопированную информацию в **reddit_app2.yml** следом за сценарием для MongoDB.

```bash
- name: Configure App
  hosts: app
  tags: app-tag
  become: true
  vars:
    db_host: 192.168.10.28
  tasks:
    - name: Add unit file for Puma
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      notify: reload puma

    - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/ubuntu/db_config
        owner: ubuntu
        group: ubuntu

    - name: enable puma
      systemd: name=puma enabled=yes

  handlers:
    - name: reload puma
      systemd: name=puma state=restarted

```
Пересоздаю инстансы и после проверю
Также напомню, что все провижены убраны и при создании инстансов взамосвязь между БД и приложением не будет настроена. Именно эти настройки наш плейбук и должен будет сделать.

```bash
terraform destroy
terraform apply
```

```bash
ansible-playbook reddit_app2.yml --tags db-tag --check
ansible-playbook reddit_app2.yml --tags db-tag
```
```bash
ansible-playbook reddit_app2.yml --tags app-tag --check
ansible-playbook reddit_app2.yml --tags app-tag
```
Спешу сообщить что вот такая ошибка вылезла

```bash
TASK [enable puma] *********************************************
fatal: [app-server]: FAILED! => {"changed": false, "msg": "Could not find the requested service puma: host"
```
Причина в том, что плейбук не стработал в боевом режиме и unit-файл puma.service еще не создан. Когда зпущу плейбук в боевом режиме ощибок не будет.

Плейбук сработал штатно, но еще деплойа приложения не было, о чем сведетельствует данная ошибка
```bash
ubuntu@reddit-app:~$ systemctl status puma
● puma.service - Puma HTTP Server
   Loaded: loaded (/etc/systemd/system/puma.service; enabled; vendor preset: enabled)
   Active: failed (Result: start-limit-hit) since Thu 2023-05-25 12:32:30 UTC; 13min ago
  Process: 1198 ExecStart=/bin/bash -lc puma (code=exited, status=217/USER)
 Main PID: 1198 (code=exited, status=217/USER)

May 25 12:32:29 reddit-app systemd[1]: puma.service: Unit entered failed state.
May 25 12:32:29 reddit-app systemd[1]: puma.service: Failed with result 'exit-code'.
May 25 12:32:30 reddit-app systemd[1]: puma.service: Service hold-off time over, scheduling restart.
May 25 12:32:30 reddit-app systemd[1]: Stopped Puma HTTP Server.
May 25 12:32:30 reddit-app systemd[1]: puma.service: Start request repeated too quickly.
May 25 12:32:30 reddit-app systemd[1]: Failed to start Puma HTTP Server.
May 25 12:32:30 reddit-app systemd[1]: puma.service: Unit entered failed state.
May 25 12:32:30 reddit-app systemd[1]: puma.service: Failed with result 'start-limit-hit'.
```

НАДО ДЕПЛОЙИТЬ ТОВАРИЩИ, НАДО ДЕПЛОЙИТЬ!!!

Добавляю сценарий для деплоя в **reddit_app2.yml**

```bash
- name: Fetch the latest version of application code # <-- Деплой/обновление
  hosts: app
  tags: deploy-tag
  become: true
  tasks:
    - name: Deploy Reddit App
      git:
        repo: "https://github.com/express42/reddit.git"
        dest: /home/ubuntu/reddit
        version: monolith # <-- Указываем нужную ветку
      notify: reload puma

    - name: Bundle install
      bundler:
        state: present
        chdir: /home/ubuntu/reddit # <-- В какой директории выполнить команд bundle
```
у хэндлек тоже

```bash
handlers:
    - name: reload puma
      systemd: name=puma state=restarted
```

И надо теперь проверить
```bash
ansible-playbook reddit_app2.yml --tags deploy-tag --check
ansible-playbook reddit_app2.yml --tags deploy-tag
```
Ошибка:
```bash
TASK [Deploy Reddit App] ***********************************************************
fatal: [app-server]: FAILED! => {"changed": false, "msg": "Failed to find required executable \"git\" in paths: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"}
```

В инстансе не установлен GIT. Надо бы его установить, но попробую запустить плейбук и может Ansible догадается, что надо  установить GIT.

НЕ ПОМОГЛО!!! НУЖЕ СЦЕНАРИЙ ДЛЯ УСТАНОВКИ git

```bash
- name: Deploy App
  hosts: app
  tags: deploy-tag
  become: true
  tasks:
  - name: Install git
      apt:
        name: git
        state: present
        update_cache: yes

...
```
Тут очень фажно соблюдать последовательность тасков

И надо еще раз  проверить
```bash
ansible-playbook reddit_app2.yml --tags deploy-tag --check
ansible-playbook reddit_app2.yml --tags deploy-tag
```
Вот результат

БИНГО!!!
```bash
PLAY RECAP *********************************************************************************************************
app-server                 : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
 Но возникла проблема с запуском **puma.service** из-за вот этой ошибки
```bash
Warning: puma.service changed on disk. Run 'systemctl daemon-reload' to reload units.
```
Для решение использовал очередной handler в **app-tag** вот в таком виде
```bash
- name: Configure App
  hosts: app
  tags: app-tag
  become: true
  vars:
    db_host: 192.168.10.26
  tasks:
    - name: Add unit file for Puma
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      notify:
        - reload systemd
        - reload puma

        ...

  handlers:
    - name: reload puma
      systemd: name=puma state=restarted

    - name: reload systemd
      command: systemctl daemon-reload
```
---

## Несколько (плейбойев UPS!!!) плейбуков

Теперь вот что! С ростом числа управляемых сервисов, будет расти количество различных сценариев и, как результат, увеличится объем плейбука.
Это приведет к тому, что в плейбуке, будет сложно разобраться. Поэтому, следующим шагом необходимо разделить плейбук на несколько.

Первым делом создам новые файлы в директории **ansible**
```bash
touch app.yml db.yml deploy.yml
```
Далее, переименую следующие файлы
```bash
mv reddit_app.yml reddit_app_one_play.yml ; mv reddit_app2.yml reddit_app_multiple_plays.yml
```

Из файла **reddit_app_multiple_plays.yml** скопирую сценарий, относящийся к настройке БД, в файл **db.yml** и при этом удаляю тег определенный в сценарии.

Аналогично вынесем настройку хоста приложения из **reddit_app_multiple_plays.yml** в отдельный плейбук **app.yml** удалив теги.

И конце создам файл **site.yml** в директории **ansible**, в котором опишу управление конфигурацией всей инфраструктуры. Это будет главным плейбуком, который будет включать в себя все остальные.

**site.yml**
```bash
---
- import_playbook: db.yml
- import_playbook: app.yml
- import_playbook: deploy.yml
```
ВСЁ ГОТОВО!
Теперь пересоздаю инстансы.
```bash
terraform destroy
terraform apply
```
Далее проверка плейбуков
```bash
ansible-playbook site.yml --check
ansible-playbook site.yml
```
Конечно, не надо забыать, что ошибки могут быть. Плейбук будет жаловатся на то, что GIT, напрмер, не установлен, хотя установка указана в плейбуке.

Результат
```bash
PLAY RECAP ******************************************************************************************************************
app-server                 : ok=11   changed=9    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
db-server                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
---

## Задание со ⭐


---

## Провижининг в Packer

В данной части необходимо изменить **provision** в **Packer** и заменить **bash-скрипты** на **Ansible-плейбуки**
Создам плейбуки **ansible/packer_app.yml** и **ansible/packer_db.yml** и будет реализован функционал **bash-скриптов**, которые использовались в **Packer** ранее
- **packer_app.yml** - установит Ruby и Bundle
- **packer_db.yml** - добавмт репозиторий **MongoDB**, устанавит ее и включит сервис

### Самостоятельное задание

Ну, чтож! Попробую описать действия в **bash-скриптах** провижина в **Packer** уже в **Ansible-плейбуках**. При этом условия такие, что использовать модули **command** и **shell** нежелательно!

Вот так выглядить плейбук **packer_db.yml**
```bash
---
- name: Install MongoDB on Packer image
  hosts: default
  become: yes
  tasks:
    - name: Import the public key used by the package management system
      apt_key:
        keyserver: hkp://keyserver.ubuntu.com:80
        id: d68fa50fea312927

    - name: Add MongoDB repository
      apt_repository:
        repo: "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse"
        state: present

    - name: "apt-get update"
      apt: update_cache=yes

    - name: install Mongodb-3.2
      apt:
        name: mongodb-org
        state: present

    - name: Configure service supervisor
      systemd:
        name: mongod
        enabled: yes
```

Необходимо отметить то, что важным моментом тут является **id** ключа GPG (GNU Privacy Guard (GnuPG, GPG) — свободная программа для шифрования информации и создания электронных цифровых подписей.), который даёт возможность устанавливать нужную версию **MongoDB**. И так, важным моментом тут является то, что
- 1. **id** ключа необходимо указывать полностью, а не первые 8 символов как описывается в сети.
- 2. при указывании ключа необходимо помнить, что **uppercase** **lowercase** важны

Но, еще не всё!
До этой стадии проблемы с ключом ранее возникла вот такая проблема при запуске плейбука
```bash
rpc error: code = Unauthenticated desc = iam token create failed: failed to get compute instance service account token from instance metadata service: GET http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token: Get "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token": dial tcp 169.254.169.254:80: i/o timeout.
Are you inside compute instance
```
Причина проблемы изложена вот тут [https://www.tune-it.ru/web/defuse/blog/-/blogs/unable-to-negotiate-with-port-22-no-matching-host-key-type-found-their-offer-ssh-dss]


А если описать словами данную проблему: Ошибка из-за того, что новая версия SSH не включает по умолчанию поддержку RSA/SHA1, то есть ssh-rsa. Вместо этого ожидается, что сервер будет использовать RSA/SHA-256/512. С более новыми серверами с более свежим SSH проблемы не будет, но в данном случае hostname более старой версии.

Еще раз: я использую образ ubuntu-16.04 для создания кастомного образа с помощью **Packer**, но при этом сценарий все запускаются в моей локальной среде которая:
```bash
cat /etc/os-release
  PRETTY_NAME="Ubuntu 22.04.2 LTS"
  NAME="Ubuntu"
  VERSION_ID="22.04"
  VERSION="22.04.2 LTS (Jammy Jellyfish)"
```
из-за чего и возникла проблема версий SSH.
А решается эта проблема с включением следующих строк в файл **~/.ssh/config** Если данного файла нет, то необхожимо создать.
```bash
Host *
    HostkeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
```
Вот и всё. В результате после запуска
```bash
packer build -var-file=variables.json db.json
```
результат таков
```bash
==> Wait completed after 2 minutes 58 seconds

==> Builds finished. The artifacts of successful builds are:
--> yandex: A disk image was created: reddit-mongodb-1685268210
```
Далее попробую создать кастомный образ уже с плейбуком **packer_app.yml**

Вот так выглядить плейбук **packer_app.yml**
```bash
---
- name: Install Ruby && Bundler
  hosts: all
  become: true
  tasks:
    - name: Pause for 1 minutes befor installing ruby set
      ansible.builtin.pause:
        minutes: 1
    # Установим в цикле все зависимости
    - name: Install ruby-full
      apt: "name=ruby-full state=present"

    - name: Pause for 1 minutes befor installing ruby-bundler
      ansible.builtin.pause:
        minutes: 1

    - name: Install ruby-bundler
      apt: "name=ruby-bundler state=present"

    - name: Pause for 1 minutes befor installing build-essential
      ansible.builtin.pause:
        minutes: 1

    - name: Install build-essential
      apt: "name=build-essential state=present"
```
Ранее, из-за возникшей проблемы
```bash
"E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), is another process using it?"]
```
пришлось разделить на отдельные таски установку компонентов Ruby и ставить паузу между ними
```bash
- name: Pause for 1 minutes befor installing ruby-bundler
      ansible.builtin.pause:
        minutes: 1
```
и вот результат
```bash
==> Wait completed after 6 minutes 3 seconds

==> Builds finished. The artifacts of successful builds are:
--> yandex: A disk image was created: reddit-ruby-1685274414
```
Вот созданные образы:
```bash
yc compute image list
+----------------------+-----------------------------+-------------+----------------------+--------+
|          ID          |            NAME             |   FAMILY    |     PRODUCT IDS      | STATUS |
+----------------------+-----------------------------+-------------+----------------------+--------+
| fd8m                 | reddit-mongodb-1685268210   | reddit-full | f2eu5d4ulcfnhspd9hmf | READY  |
| fd8n                 | reddit-ruby-1685274414      | reddit-full | f2eu5d4ulcfnhspd9hmf | READY  |
+----------------------+-----------------------------+-------------+----------------------+--------+
```
Теперь на основе созданных образов запускаю **stage** окружение. При  этом необходимо указать **id** вновь созданных образов в переменных
```bash
variable "app_disk_image" {
  description = "Disk image for reddit app"
  default     = "fd82" # image created by Packer with installed Ruby named "reddit-ruby-1685274414"
}
variable "db_disk_image" {
  description = "Disk image for reddit db"
  default     = "fd8t" # image created by Packer with installed MongoDB named "reddit-mongodb-1685268210"
}
```
```bash
ansible-playbook site.yml
```

БИНГО!!! РАБОТАЕТ.

НА ЭТОМ ВСЁ
