#!/bin/bash
# Bibliothèque de templating

# Fonction pour générer un fichier depuis un template
# Usage: generate_from_template <template_file> <output_file> <var1> <value1> [<var2> <value2> ...]
generate_from_template() {
    local template_file=$1
    local output_file=$2
    shift 2
    
    if [ ! -f "$template_file" ]; then
        echo "❌ Template introuvable: $template_file"
        return 1
    fi
    
    # Lire le template
    local content=$(cat "$template_file")
    
    # Remplacer les variables
    while [ $# -gt 0 ]; do
        local var=$1
        local value=$2
        content="${content//\{\{${var}\}\}/$value}"
        shift 2
    done
    
    # Écrire le fichier de sortie
    echo "$content" > "$output_file"
    
    return 0
}

# Fonction simplifiée avec variables d'environnement
# Usage: render_template <template_file> <output_file>
render_template() {
    local template_file=$1
    local output_file=$2
    
    if [ ! -f "$template_file" ]; then
        echo "❌ Template introuvable: $template_file"
        return 1
    fi
    
    # Lire le template
    local content=$(cat "$template_file")
    
    # Remplacer automatiquement toutes les variables d'environnement
    # Chercher {{VAR}} et remplacer par $VAR
    while IFS= read -r line; do
        # Extraire les variables {{XXX}}
        vars=$(echo "$line" | grep -oP '\{\{[A-Z_]+\}\}' | sort -u)
        for var_placeholder in $vars; do
            var_name=$(echo "$var_placeholder" | sed 's/{{//;s/}}//')
            var_value="${!var_name}"
            content="${content//$var_placeholder/$var_value}"
        done
    done <<< "$content"
    
    # Écrire
    echo "$content" > "$output_file"
    
    return 0
}
