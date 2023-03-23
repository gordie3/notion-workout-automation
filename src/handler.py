from notion import get_pending_workouts, create_workout_children

def handler(event, context):
    pending_workouts = get_pending_workouts()
    for workout in pending_workouts:
        create_workout_children(workout)
