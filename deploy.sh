#!/bin/bash

creator_config () { 
	echo "----------------------------------------------------------------------";
	echo "                Criando o arquivo de configuração                     ";
	echo "----------------------------------------------------------------------";
	echo "Informe o ssh do servidor (Ex: user@servidor): ";
	read ssh_config;
	echo 'ssh="'$ssh_config'"' >> apps/$project".conf";

	echo "Informe o caminho remoto projeto ( Ex: /var/www/projeto/app): ";
	read path_config;
	echo 'path_remote="'$path_config'"' >> apps/$project".conf";
	
	echo "Informe a branch de desenvolvimento ( Ex: develop): ";
	read branch_dev_config;
	echo 'branch_dev="'$branch_dev_config'"' >> apps/$project".conf";
	
	echo "Informe a branch de estavel ( Ex: master): ";
	read branch_prod_config;
	echo 'branch_prod="'$branch_prod_config'"' >> apps/$project".conf";
}

# Lendo configurações gerais
. conf/general.conf

echo "======================================================================";
echo "                         Processo de deploy                           ";
echo "======================================================================";

echo "Informe o projeto que deseja fazer deploy: ";

read project;
echo "----------------------------------------------------------------------";
echo "                     Lendo arquivo de configuração                    ";

# Verifica se existe o arquivo de configuração, se não tiver, ele pergunta se quer criar
if [ ! -e apps/$project.conf ] ; then
	echo "Arquivo de configuração não existe. Vamos criar? [s]im / [n]ão";

	read confirmation;

	if [ $confirmation == 's' ]; then
		creator_config;
	else
		echo "----------------------------------------------------------------------";
		echo " 		     Instruções para criação do arquivo de configuração: 		";
		echo "----------------------------------------------------------------------";
		echo "1. crie o arquivo $project no diretório config/";
		echo "2. no arquivo, preencha as variaveis pré-definidas abaixo: ";
		echo '- ssh="usuario@servidor"';
		echo '- path_remote="/var/www/html/projeto.com.br"';
		echo '- branch_dev="develop"';
		echo '- branch_prod="master"';
		exit;
	fi
fi

# Adicionando variaveis de configuração no shell
. apps/$project.conf

# Acessando a pasta do projeto
cd $path_projects/$project;

git checkout $branch_prod;

new_version=$(git tag | sort -V | tail -n1);
current_version=$(git tag | sort -V | tail -n2 | head -n1);

# Verifica se é para realizar o rollback do projeto
if [ $1 == '--rollback' ]; then
	echo "----------------------------------------------------------------------";
	echo "************* ATENÇÃO, SERÁ REALIZADO O ROLLBACK DO PROJETO **********";
	echo "----------------------------------------------------------------------";
	echo "Informe a versão que está o projeto: ";
	read current_version;
	echo "Informe para qual versão voltar: ";
	read new_version;
	echo "----------------------------------------------------------------------";

	git checkout $new_version;
fi

# Verifica se foi passado a versão atual, caso tenha sido passado, ele pega a diferença entre as versões
if [ $1 == '--v' ]; then
	current_version=$2
fi

echo "----------------------------------------------------------------------";
echo " Versão atual: "$current_version;
echo " Nova versão: "$new_version;
echo " A versão atual é "$current_version "que será subustituida pela versão " $new_version;
echo "----------------------------------------------------------------------";

echo "Deseja realmente aplicar o deploy dessa versão? [s]im / [n]ão";

read confirmacao;

if [ $confirmacao == 'n' ]; then
	echo "----------------------------------------------------------------------";
	echo "              Processo de deploy cancelado pelo usuário               ";
	echo "----------------------------------------------------------------------";
	exit;
fi

if [ ! -d $path_deploy ]; then
	mkdir $path_deploy;
fi

if [ ! -d $path_deploy/$project ]; then
	mkdir $path_deploy/$project
fi

mkdir $path_deploy/$project/$new_version;

echo "----------------------------------------------------------------------";
echo "                 Verificando diferença entre versões                  ";

cp -rfv $(git diff --diff-filter=ACMRT --name-only $current_version $new_version)    $path_deploy/$project/$new_version --parents;
echo   "$(git diff --diff-filter=D     --name-only $current_version $new_version)" > $path_deploy/$project/$new_version/deletados.txt;
echo   "$(git diff --diff-filter=ACMRT --name-only $current_version $new_version)" > $path_deploy/$project/$new_version/alterados.txt;
echo   "$new_version" > $path_deploy/$project/$new_version/versao.txt;

# Voltando para a branch develop
git checkout $branch_dev;

cd $path_deploy/$project/$new_version;

echo "----------------------------------------------------------------------";
echo "                        Compactando arquivos                          ";

zip -r $new_version.zip $new_version *

mv $path_deploy/$project/$new_version/$new_version.zip ../

rm -r $path_deploy/$project/$new_version

echo "----------------------------------------------------------------------";
echo "                     Copiando para o servidor                         ";

#scp $path_deploy/$project/$new_version.zip $ssh:$path_remote/app.zip

echo "----------------------------------------------------------------------";
echo "                    Acessando e aplicando deploy                      ";

#ssh $ssh "cd $path_remote ; unzip -o app.zip ; rm app.zip ; xargs rm -fv < deletados.txt ; mv versao.txt webroot/versao.txt ; chmod 777 tmp/ webroot/versao.txt ; find tmp -type f -delete";

echo "======================================================================";
echo "        Publicação da versão $new_version realizada com sucesso!      ";
echo "======================================================================";