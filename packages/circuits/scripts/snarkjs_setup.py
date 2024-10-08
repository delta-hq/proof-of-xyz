import modal
import logging
import os
import json
import random
import sys

# Define the Modal app
app = modal.App("snarkjs-setup")

# Define the Docker image
image = modal.Image.from_dockerfile("Dockerfile")

@app.function(
    image=image,
    mounts=[
        modal.Mount.from_local_file("coinbase.r1cs", remote_path="/root/coinbase.r1cs"),  # Change as necessary
    ],
    cpu=60,
    gpu="any",
    secrets=[modal.Secret.from_name("obl-zkdemo")],
    keep_warm=True
)
@modal.wsgi_app()
def flask_app():
    # Define the Flask app
    app = Flask(__name__)

    @app.post("/run")
    def run():
        # Get the contribution from the request
        req = request.get_json()
        contribution = req.get("contribution", "contributionrandom")  # Default contribution
        logging.info(f"Received contribution: {contribution}")

        # Run the snarkjs commands
        result = run_snarkjs_commands.call(contribution)
        logging.info(f"SNARKJS commands executed with contribution: {contribution}")

        # Return a success response
        return jsonify({"message": "SNARKJS commands executed successfully", "contribution": contribution}), 200

    return app

@app.function(
    image=image,
    cpu=60,
)
def run_snarkjs_commands(contribution):
    import os

    # Run the snarkjs commands as before
    os.system("snarkjs powersoftau new bn128 5 pot12_0000.ptau -v")
    os.system(f'echo "{contribution}" | snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v')
    os.system("snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v")
    # Uncomment if you want to include groth16 setup
    # os.system(f"snarkjs groth16 setup coinbase.r1cs pot12_final.ptau coinbase_0000.zkey")

