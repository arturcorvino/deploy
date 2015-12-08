#!/bin/bash

# Lendo configurações gerais
. conf/geral.conf

echo "----------------------------------------------------------------------";
echo "                         Processo de deploy                           ";
echo "----------------------------------------------------------------------";

echo "Informe o projeto que deseja fazer deploy: ";

read projeto;

echo "----------------------------------------------------------------------";
echo "                     Lendo arquivo de configuração                    ";

# Adicionando variaveis de configuração no shell
. conf/$projeto.conf

# Acessando a pasta do projeto
cd $path_projetos/$projeto;

git checkout master;

versao_nova=$(git tag | sort -V | tail -n1);
versao_atual=$(git tag | sort -V | tail -n2 | head -n1)

# Verifica se é para realizar o rollback do projeto
if [ $1 == '--rollback' ]; then
	echo "----------------------------------------------------------------------";
	echo "************* ATENÇÃO, SERÁ REALIZADO O ROLLBACK DO PROJETO **********";
	echo "----------------------------------------------------------------------";
	echo "Informe a versão que está o projeto: ";
	read versao_atual;
	echo "Informe para qual versão voltar: ";
	read versao_nova;
	echo "----------------------------------------------------------------------";

	git checkout $versao_nova;
fi

# Verifica se foi passado a versão atual, caso tenha sido passado, ele pega a diferença entre as versões
if [ $1 == '--v' ]; then
	versao_atual=$2
fi

echo "----------------------------------------------------------------------";
echo " Versão atual: "$versao_atual;
echo " Nova versão: "$versao_nova;
echo " A versão atual é "$versao_atual "que será subustituida pela versão " $versao_nova;
echo "----------------------------------------------------------------------";

echo "Deseja realmente aplicar o deploy dessa versão? [S]im / [n]ão";

read confirmacao;

if [ $confirmacao == 'n' ]; then
	echo "----------------------------------------------------------------------";
	echo "              Processo de deploy cancelado pelo usuário               ";
	echo "----------------------------------------------------------------------";
	exit;
fi

mkdir $path_deploy;

if [ ! -d $path_deploy/$projeto ]; then
	mkdir $path_deploy/$projeto
fi

mkdir $path_deploy/$projeto/$versao_nova;

echo "----------------------------------------------------------------------";
echo "                 Verificando diferença entre versões                  ";

cp -rfv $(git diff --diff-filter=ACMRT --name-only $versao_atual $versao_nova)    $path_deploy/$projeto/$versao_nova --parents;
echo   "$(git diff --diff-filter=D     --name-only $versao_atual $versao_nova)" > $path_deploy/$projeto/$versao_nova/deletados.txt;
echo   "$(git diff --diff-filter=ACMRT --name-only $versao_atual $versao_nova)" > $path_deploy/$projeto/$versao_nova/alterados.txt;
echo   "$versao_nova" > $path_deploy/$projeto/$versao_nova/versao.txt;

# Voltando para a branch develop
git checkout develop;

cd $path_deploy/$projeto/$versao_nova;

echo "----------------------------------------------------------------------";
echo "                        Compactando arquivos                          ";

zip -r $versao_nova.zip $versao_nova *

mv $path_deploy/$projeto/$versao_nova/$versao_nova.zip ../

rm -r $path_deploy/$projeto/$versao_nova

echo "----------------------------------------------------------------------";
echo "                     Copiando para o servidor                         ";

scp $path_deploy/$projeto/$versao_nova.zip $ssh:$path_remoto/app.zip

echo "----------------------------------------------------------------------";
echo "                    Acessando e aplicando deploy                      ";

ssh $ssh "cd $path_remoto ; unzip -o app.zip ; rm app.zip ; xargs rm -fv < deletados.txt ; mv versao.txt webroot/versao.txt ; chmod 777 tmp/ webroot/versao.txt ; find tmp -type f -delete";

echo "======================================================================";
echo "        Publicação da versão $versao_nova realizada com sucesso!      ";
echo "======================================================================";