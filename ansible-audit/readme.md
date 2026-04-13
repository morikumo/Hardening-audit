Build l'image :
```sh
docker build -t ubuntu-ssh .
```

Lance les 2 conteneurs :

```sh
docker run -d --name target-01 --hostname target-01 ubuntu-ssh
docker run -d --name target-02 --hostname target-02 ubuntu-ssh
```
Vérifie qu'ils tournent :
```sh
docker ps
```


Etape 2:
```sh
docker inspect target-01 | grep IPAddress
docker inspect target-02 | grep IPAddress
```
