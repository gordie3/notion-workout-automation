import json
import os
import time
from typing import Any, Dict, Iterable, Optional

import requests

NOTION_INTEGRATION_TOKEN = os.getenv("NOTION_INTEGRATION_TOKEN")
NOTION_ROUTINE_LOG_DATABASE_ID = os.getenv("NOTION_ROUTINE_LOG_DATABASE_ID")
NOTION_EXERCISE_DATABASE_ID = os.getenv("NOTION_EXERCISE_DATABASE_ID")


def get_pending_workouts() -> Iterable[Dict[str, Any]]:
    print("Fetching Pending Workouts")
    body = {"filter": {"property": "Status", "select": {"equals": "Created"}}}
    api = f"/v1/databases/{NOTION_ROUTINE_LOG_DATABASE_ID}/query"
    response = _call_notion_api("POST", api, data=json.dumps(body))
    return response["results"]


def create_workout_children(workout: Dict[str, Any]):
    # Get Page
    workout_id = workout["id"]
    print(f"Adding exercises for workout: {workout_id}")
    page = _call_notion_api("GET", f'/v1/pages/{workout_id}')

    # Get Page for routine
    date = page["properties"]["Date"]["date"]["start"]
    routine_page_id = page["properties"]["Routine"]["relation"][0]["id"]
    routine_page = _call_notion_api(
        "GET", f"/v1/blocks/{routine_page_id}/children")

    # Get Database of exercises
    exercise_db = ""
    for result in routine_page["results"]:
        if result["type"] == "child_database" and result["child_database"]["title"] == "Routine Exercises":
            exercise_db = result["id"]
    if not exercise_db:
        print("No exercises for routine")
        return

    # Create Exercises
    db_pages = _call_notion_api("POST", f"/v1/databases/{exercise_db}/query")
    exercises_for_plan = db_pages["results"]
    print(f"Creating {len(exercises_for_plan)} exercises for {workout_id}")
    for db_page in exercises_for_plan:
        _create_exercise_entries(db_page, date, workout_id)

    # Set Routine to Ready
    print(f"Setting routine {workout_id} to ready")
    payload = {
        "properties": {
            "Status": {"select": {"name": "Ready"}},
        }
    }
    _call_notion_api(
        "PATCH", f"/v1/pages/{workout_id}", data=json.dumps(payload))
    print(f"Completed updating workout {workout_id}")


def _create_exercise_entries(exercise: Dict[str, Any], date: str, workout_id: str):
    properties = exercise["properties"]
    name = properties["Name"]["title"][0]["plain_text"]
    index = properties["Order"]["number"]
    sets = properties["Sets"]["number"]
    expected_reps = properties["Reps"]["rich_text"][0]["plain_text"]
    linked_exercise = properties["Exercise"]["relation"][0]["id"]

    # Create one entry per set
    for set in range(sets):
        payload = {
            "parent": {"database_id": NOTION_EXERCISE_DATABASE_ID},
            "properties": {
                "Name": {
                    "title": [
                          {
                              "text": {
                                  "content": name
                              }
                          }
                    ]
                },
                "Date": {"date": {"start": date}},
                "Index": {"number": index},
                "Set": {"number": set + 1},
                "Exercise": {"relation": [{"id": linked_exercise}]},
                "Gen 2 Plan Log": {"relation": [{"id": workout_id}]},
                "Expected Reps": {"rich_text": [{"type": "text", "text": {"content": expected_reps}}]}
            }
        }
        _call_notion_api("POST", "/v1/pages", data=json.dumps(payload))
        # Sleep so we dont get rate limited
        time.sleep(0.33)


def _call_notion_api(method: str, api: str, data: Optional[str] = None):
    print(f"Executing API {method} {api}")
    headers = {
        "Authorization": f"Bearer {NOTION_INTEGRATION_TOKEN}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    }
    response = requests.request(
        method, f"https://api.notion.com{api}", headers=headers, data=data)
    response.raise_for_status()
    return response.json()
