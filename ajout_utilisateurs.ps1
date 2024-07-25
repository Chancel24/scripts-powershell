# Détecter le domaine Active Directory
function Get-ADDomainBase {
    try {
        $rootDSE = Get-ADRootDSE
        $defaultNamingContext = $rootDSE.defaultNamingContext
        return $defaultNamingContext
    } catch {
        Write-Host "Erreur : Impossible de récupérer le contexte de nommage par défaut." -ForegroundColor Red
        exit 1
    }
}


# Spécifiez le chemin du fichier texte
$fichier = ".\liste_des_utilisateurs.txt"

# Spécifiez votre base de domaine
$baseDomaine = Get-ADDomainBase

# Lire le fichier ligne par ligne
$utilisateurs = Get-Content $fichier

foreach ($ligne in $utilisateurs) {
    # Séparer les éléments de chaque ligne en utilisant un point-virgule comme séparateur
    $elements = $ligne -split "`t"
    $nom = $elements[0]
    $prenom = $elements[1]
    $login = $elements[2]
    $mdp = $elements[3]
    $ouChemin = $elements[4] # Enlever les espaces inutiles autour de l'OU
    $nomGroupe = $elements[5]


    $ouElements = $ouChemin -split ">"
    # Construire le DN de l'OU en ajoutant les éléments dans l'ordre inverse du tableau
    $ouDN = ""
    foreach ($element in $ouElements) {
    	$ouDN = "OU=$element," + $ouDN
    }

    # Ajouter la base de domaine à la fin du DN
    $ouDN = "$ouDN$baseDomaine"


    # Vérifier si l'utilisateur existe déjà
    $utilisateurExiste = Get-ADUser -Filter { GivenName -eq $prenom -and Surname -eq $nom  }

    if (-not $utilisateurExiste) {
        # Construire le nom complet
        $nomComplet = "$prenom $nom"

        # Créer l'utilisateur
        New-ADUser -Name $nomComplet `
                   -GivenName $prenom `
                   -Surname $nom `
                   -SamAccountName $login `
                   -UserPrincipalName "$login@domain.com" `
                   -Path $ouDN `
                   -AccountPassword (ConvertTo-SecureString $mdp -AsPlainText -Force) `
                   -Enabled $true `
                   -PasswordNeverExpires $false `
                   -ChangePasswordAtLogon $true

        Write-Output "Utilisateur $login créé avec succès dans l'OU $ouDN."
    } else {
        Write-Output "Utilisateur $login existe déjà."
    }
   
        #Vérifier si le groupe existe
   	$groupeExiste = Get-ADGroup -Filter { Name -eq $nomGroupe } -SearchBase $ouDN

	if (-not $groupeExiste) {
    		New-ADGroup -Name $nomGroupe -GroupScope Global -GroupCategory Security -Path $ouDN
    		Write-Output "Groupe de sécurité $nomGroupe créé avec succès dans l'OU $ouDN."
	} else {
    	Write-Output "Groupe de sécurité $nomGroupe existe déjà dans l'OU $ouDN."
	}
        
 	# Vérifier si l'utilisateur est déjà membre du groupe
    $membreDuGroupe = Get-ADGroupMember -Identity $nomGroupe | Where-Object { $_.SamAccountName -eq $login }

    # Ajouter l'utilisateur créé au groupe de sécurité s'il n'en fait pas déjà partie
    if (-not $membreDuGroupe) {
        Add-ADGroupMember -Identity $nomGroupe -Members $login
        Write-Output "Utilisateur $login ajouté au groupe de sécurité $nomGroupe."
    } else {
        Write-Output "Utilisateur $login fait déjà partie du groupe de sécurité $nomGroupe."
    }
}
