Event Producer
This directory contains a containerized Python script (generate_events.py) that acts as the data source for the real-time pipeline.

It simulates a continuous stream of complex, "dirty" user behavioral data and sends it as JSON messages to an AWS SQS queue.

Data Features
This script is designed to test the robustness of the downstream transformation pipeline. It intentionally generates inconsistent and incomplete data, including:

Rich Dimensions: Events include marketing (utm_source, utm_medium), device (ip_address, user_agent), and transactional (order_id, quantity, value) data.
Logical Prices: A fixed price catalog is generated at startup to ensure product_id and value are consistent.
Null / "Guest" Data: Randomly generates null values for user_id and product_id.
Orphan Data: Generates user_ids and product_ids that do not exist in our seeds data, testing referential integrity.
Inconsistent Formats:
    event_timestamp is sent as either an ISO string or a Unix epoch integer.
    event_type is sent with inconsistent casing (e.g., checkout, CHECKOUT, Checkout).
Duplicates: Occasionally sends the same event_id twice to test the pipeline's de-duplication logic.

How to Run
1. Prerequisites
Docker Desktop must be running.

Your local AWS CLI must be configured (aws configure) with credentials that have sqs:SendMessage permission on the target queue.

2. Build the Image
You must re-build the image every time you make a change to the generate_events.py script. Run from the root directory of the project

docker build -t realtime-producer:v1 ./producer

3. Run the Container
This command starts the producer and mounts your local AWS credentials into the container. Run from the root directory of the project

docker run --rm -v ${HOME}/.aws:/root/.aws realtime-producer:v1