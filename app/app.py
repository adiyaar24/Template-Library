import requests
import os
from json import loads

from flask import Flask, jsonify, request
import concurrent.futures

app = Flask(__name__)

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
# Replace with the owner of the repository
REPO_OWNER = os.getenv("REPO_OWNER")
# Replace with the repository name
REPO_NAME = os.getenv("REPO_NAME")


def get_file_content(file_path):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{file_path}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3.raw",
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.text
    else:
        print(
            f"Error fetching {file_path}: {response.status_code} message : {response.message}"
        )
        return None


def fetch_templates(directory):
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/{directory}"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        contents = response.json()
        results = []
        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = []
            for item in contents:
                if item["type"] == "dir":
                    futures.append(executor.submit(fetch_templates, item["path"]))
                elif item["type"] == "file" and item["name"].lower() == "_info.json":
                    futures.append(
                        executor.submit(
                            process_readme, item["path"], directory, contents
                        )
                    )
            for future in concurrent.futures.as_completed(futures):
                result = future.result()
                if result:
                    results.extend(result)
        return results
    else:
        print(f"Error fetching directory {directory}: {response.status_code}")
        return []


def process_readme(file_path, directory, contents):
    file_content = get_file_content(file_path)
    if file_content:
        parsed_info = loads(file_content)
        display = any(item["name"] == "main.tf" for item in contents)
        return [
            {
                "path": file_path,
                "info": parsed_info,
                "directory": directory,
                "display": display,
            }
        ]
    return []


@app.route("/fetch_templates", methods=["GET"])
def fetch_templates_endpoint():
    directory = request.args.get("directory", "")
    category_filter = request.args.get("category", "").lower()
    search_query = request.args.get("search", "").lower()

    templates = fetch_templates(directory)

    filtered_templates = {"templates": []}
    for template in templates:
        info = template["info"]
        key_values = info.get("key_values")
        if not key_values:
            print(f'broken template: {template.get("path")}')
            continue

        if (
            category_filter
            and key_values.get("Category", "").lower() != category_filter
        ):
            continue

        if search_query and search_query not in key_values.get("Name", "").lower():
            continue

        filtered_templates["templates"].append(template)

    response = jsonify(filtered_templates)
    response.headers.add("Access-Control-Allow-Origin", "*")
    return response


@app.route("/health_check", methods=["GET"])
def health_check_endpoint():
    return "Healthy"


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")
