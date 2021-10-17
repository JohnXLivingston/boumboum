# boumboum

Ceci est un petit proof of concept pour répondre au challenge lancé par Yves Rougy ici : https://twitter.com/yrougy/status/1449819488896040960

Le but est de faire un programme qui génère un maximum de load average, en utilisant le moins de RAM possible.

Il faut être en mesure de choisir la charge à créer à l'avance.

## Description de ma solution

### Motivations

L'idée est d'avoir une sorte de «fork bomb», mais dont le nombre de fork est controlable.

Point important : je ne veux modifier aucune variable, pour faire jouer au max le copy-on-write.
En effet, quand on fork un process, sa pile est copiée. Mais, il existe un mécanisme, https://fr.wikipedia.org/wiki/Copy-on-write ,
qui fait que le noyau ne duplique réellement les zones mémoires (aussi bien la partie executable, que la pile) que s'il y a modification.

### La solution proposée

Pour faire simple et efficace, et être sûr de ne rien modifier en mémoire... j'ai choisi de générer du code C via un script perl.
Le code C généré est tout simplement N `fork();`, sans récupérer la valeur de retour.
Puis un `while(1) sleep(T)`, avec une durée qu'on peut choisir en paramètre. Histoire de pouvoir jouer sur le temps CPU consommé.

Et pour ne pas freezer la machine, on ajoute un `nice -19` avant de lancer la bombe.

Le code perl :

```perl
#!/usr/bin/perl

my $nb = int($ARGV[0]) || 100;
my $sleep = $ARGV[1] || '1';
my $nice = 19;

print "nb=$nb sleep=$sleep nice=$nice\n";

my $fork = "fork();" x $nb;
my $prog = <<EOF;
#include <sys/types.h>
#include <unistd.h>

int
main() {
	$fork
	while(1) {
		sleep($sleep);
	}
	return 0;
}

EOF

open(FH, '>', 'boum.c') or die $!;
print FH $prog;
close(FH);

`cc -o boum boum.c`;
`nice -$nice ./boum`;
```

Qui va générer un fichier C :

```C
#include <sys/types.h>
#include <unistd.h>

int
main() {
	fork();fork();fork();fork();fork();fork();fork();fork();fork();fork();
	while(1) {
		sleep(0.1);
	}
	return 0;
}
```

## Utilisation

Pré-requis : avoir perl et le compilateur cc.

Pour lancer la bombe :

```shell
perl boum.pl 10 0.10
```

Le premier paramètre (10), c'est le nombre de fork() qu'il va y avoir dans le code C généré.

Attention ! Le nombre de processus va être bien plus grand que le nombre de `fork` !
Et oui, chaque fork va doubler le nombre de processus... Ce qui fait une progression exponentielle en 2^N !
Pour une valeur passée de 10, on aura donc 1024 processus !
Ce qui, sur une petite VM de test, fait déjà un load average de plus de 700 (avec un sleep à 0.1).


Et niveau utilisation mémoire...

```bash
$ # Avant de lancer.
$ free -b
               total       utilisé      libre     partagé tamp/cache   disponible
Mem:      4122259456    89837568  3857805312      143360   174616576  3817267200
Partition d'échange: 1023406080   185860096   837545984

$ # Après avoir lancé
$ free -b
               total       utilisé      libre     partagé tamp/cache   disponible
Mem:      4122259456   191909888  3753742336      143360   176607232  3714199552
Partition d'échange: 1023406080   185860096   837545984


$ # Après avoir coupé
$ free -b
               total       utilisé      libre     partagé tamp/cache   disponible
Mem:      4122259456    90882048  3856605184      143360   174772224  3816144896
Partition d'échange: 1023406080   185860096   837545984

```

Remarque : je ne suis pas sûr que l'utilisation mémoire affichée par l'OS soit pertinente, à cause du copy on write.
Je pense qu'il faut plutôt regarder les changements sur la mémoire disponible.

Dans l'exemple donné ci dessus, le delta sur la mémoire disponible est de l'ordre de 100Mo de RAM. 

Sur ma petite VM de test, si je met 15 comme paramètre, j'ai très vite des erreurs de type
`-bash: fork: retry: Ressource temporairement non disponible`.
Je ne suis pas sûr de comprendre pourquoi. Il y a sans doute une limite à 32000 processus quelque part.

