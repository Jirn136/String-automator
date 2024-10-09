#!/bin/bash

# Function to read user input for spreadsheet details, languages, and columns
read_user_input() {
    echo "Enter the Google Spreadsheet ID:"
    read SPREADSHEET_ID
    echo "Enter the Google Sheets Range (e.g., Sheet1!A:F):"
    read RANGE_NAME
    echo "Enter the path to the credentials JSON file (e.g., ./credentials.json):"
    read CREDENTIALS_PATH
    echo "Enter the languages you want to generate files for (space-separated, e.g., en de fr):"
    read -a LANGUAGES
    echo "Enter the column numbers for each language (space-separated, e.g., 3 4 5):"
    read -a LANGUAGE_COLUMNS
}

# Get user input
read_user_input

# Install required dependencies if not installed
pip install gspread oauth2client xmltodict --quiet

# Python script embedded within the shell script
python3 <<EOF
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import xml.etree.ElementTree as ET
import json
import os

# Configuration from user input
SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']
SPREADSHEET_ID = "$SPREADSHEET_ID"
RANGE_NAME = "$RANGE_NAME"
LANGUAGES = ${LANGUAGES[@]}
LANGUAGE_COLUMNS = ${LANGUAGE_COLUMNS[@]}

def authenticate_google_sheets(credentials_path):
    creds = ServiceAccountCredentials.from_json_keyfile_name(credentials_path, SCOPES)
    client = gspread.authorize(creds)
    return client

def fetch_strings(sheet, lang_column_index):
    data = sheet.get(RANGE_NAME)
    strings = {}
    plurals = {}

    for row in data[1:]:  # Skip header row
        key, type_value, quantity, *translations = row
        value = translations[lang_column_index]

        if type_value.lower() == "plural":
            if key not in plurals:
                plurals[key] = {}
            plurals[key][quantity] = value
        elif type_value.lower() == "string":
            strings[key] = value

    return strings, plurals

def create_strings_xml(strings, plurals, lang_code):
    resources = ET.Element('resources')

    # Add regular strings
    for key, value in strings.items():
        string_elem = ET.SubElement(resources, 'string', name=key)
        string_elem.text = value

    # Add plural strings
    for key, quantities in plurals.items():
        plural_elem = ET.SubElement(resources, 'plurals', name=key)
        for quantity, value in quantities.items():
            item_elem = ET.SubElement(plural_elem, 'item', quantity=quantity)
            item_elem.text = value

    output_dir = f"res/values-{lang_code}"
    os.makedirs(output_dir, exist_ok=True)
    tree = ET.ElementTree(resources)
    tree.write(f'{output_dir}/strings.xml', encoding='utf-8', xml_declaration=True)

def main():
    credentials_path = "$CREDENTIALS_PATH"
    client = authenticate_google_sheets(credentials_path)
    sheet = client.open_by_key(SPREADSHEET_ID).sheet1

    for lang_index, lang_code in enumerate(LANGUAGES):
        strings, plurals = fetch_strings(sheet, LANGUAGE_COLUMNS[lang_index] - 1)  # Adjust for column offset
        create_strings_xml(strings, plurals, lang_code)

if __name__ == '__main__':
    main()
EOF

echo "String files have been generated in the 'res' directory based on your preferences."
