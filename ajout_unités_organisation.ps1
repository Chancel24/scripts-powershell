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

# Ajouter les unités d'organisation dans l'AD
function Add-OUs {
    param (
        [string]$domainBase,
        [string]$ouFilePath
    )

    if (-Not (Test-Path -Path $ouFilePath)) {
        Write-Host "Erreur : Le fichier spécifié n'existe pas." -ForegroundColor Red
        exit 1
    }

    $ous = Get-Content -Path $ouFilePath

    foreach ($ou in $ous) {
        try {
            $ouParts = $ou -split '>'
            $parentPath = $domainBase

            foreach ($part in $ouParts) {
                $part = $part.Trim(" ","`t")
                $ouPath = "OU=$part,$parentPath"
	
                # Vérifier si l'OU existe déjà avant de la créer
                if (-Not (Get-ADOrganizationalUnit -Filter "Name -eq '$part'" -SearchBase $parentPath -ErrorAction SilentlyContinue)) {
                    New-ADOrganizationalUnit -Name $part -Path $parentPath -ErrorAction Stop
                    Write-Host "L'unité d'organisation '$part' a été ajoutée avec succès à $ouPath." -ForegroundColor Green
		     
                } else {
                    Write-Host "L'unité d'organisation '$part' existe déjà"
                }

                # Mettre à jour le chemin parent pour la prochaine itération
                $parentPath = $ouPath
            }
        } catch {
            Write-Host "Erreur : Impossible d'ajouter l'unité d'organisation '$ou'. $_" -ForegroundColor Red
        }
    }
}

# Chemin relatif vers le fichier contenant les OUs
$ouFilePath = ".\liste_unités_organisation.txt"

# Importer le module Active Directory
Import-Module ActiveDirectory

# Récupérer le domaine AD
$domainBase = Get-ADDomainBase

# Afficher le domaine
Write-Host "Domaine Active Directory détecté : $domainBase" -ForegroundColor Cyan

# Ajouter les OUs
Add-OUs -domainBase $domainBase -ouFilePath $ouFilePath
