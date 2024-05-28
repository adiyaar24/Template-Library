import re
import requests
import os
from flask import Flask, jsonify, request
import concurrent.futures

app = Flask(__name__)

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
# Replace with the owner of the repository
REPO_OWNER = os.environ["REPO_OWNER"]
# Replace with the repository name
REPO_NAME = os.environ["REPO_NAME"]

def get_file_content(file_path):
    url = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}'
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3.raw'
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.text
    else:
        print(f'Error fetching {file_path}: {response.status_code} message : {response.message}')
        return None

def extract_info_from_readme(content):
    # Extract key-value pairs
    # key_value_pattern = re.compile(r'^(\w+):\s*\'([^\']*)\'', re.MULTILINE)
    # key_values = {match.group(1): match.group(2) for match in key_value_pattern.finditer(content)}
    
    table_pattern = re.compile(r'\| *(\w+) *\| *([^|]+) *\|\n')
    key_values = {match.group(1): match.group(2).strip() for match in table_pattern.finditer(content)}
    
    # Extract headings and content
    headings = []
    current_heading = None
    
    for line in content.splitlines():
        if line.startswith('##'):
            if current_heading is not None:
                headings.append({'level': current_heading['level'], 'text': current_heading['text'], 'content': current_content.strip()})
            current_heading = {'level': line.count('#'), 'text': line.strip('#').strip()}
            current_content = ''
        elif current_heading is not None:
            current_content += line.strip() + '\n'
    
    if current_heading is not None:
        headings.append({'level': current_heading['level'], 'text': current_heading['text'], 'content': current_content.strip()})
    
    return {
        'key_values': key_values,
        'headings': headings
    }

def fetch_templates(directory):
    url = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{directory}'
    headers = {
         'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        contents = response.json()
        results = []
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            for item in contents:
                if item['type'] == 'dir':
                    futures.append(executor.submit(fetch_templates, item['path']))
                elif item['type'] == 'file' and item['name'].lower() == 'readme.md':
                    futures.append(executor.submit(process_readme, item['path'],directory, contents))
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result:
                    results.extend(result)
        return results
    else:
        print(f'Error fetching directory {directory}: {response.status_code}')
        return []

def process_readme(file_path,directory, contents):
    file_content = get_file_content(file_path)
    if file_content:
        parsed_info = extract_info_from_readme(file_content)
        display = any(item['name'] == 'main.tf' for item in contents)
        return [{
            'path': file_path,
            'info': parsed_info,
            'directory': directory,
            'display': display
        }]
    return []

@app.route('/fetch_templates', methods=['GET'])
def fetch_templates_endpoint():
    directory = request.args.get('directory', '')
    category_filter = request.args.get('category', '').lower()
    search_query = request.args.get('search', '').lower()
    
    templates = fetch_templates(directory)
    
    filtered_templates = []
    for template in templates:
        info = template['info']
        key_values = info['key_values']
        
        if category_filter and key_values.get('Category', '').lower() != category_filter:
            continue
        
        if search_query and search_query not in key_values.get('Name', '').lower():
            continue
        
        filtered_templates.append(template)
    
    return jsonify(filtered_templates)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')

