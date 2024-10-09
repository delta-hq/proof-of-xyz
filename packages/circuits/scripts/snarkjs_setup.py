import modal
import logging
import os

# Define the Modal app
app = modal.App("snarkjs-setup")
vol = modal.Volume.from_name("ptau")

# Define the Docker image
image = modal.Image.from_dockerfile("Dockerfile")

@app.function(
    image=image,
    mounts=[
        modal.Mount.from_local_file("coinbase.r1cs", remote_path="/root/coinbase.r1cs"),
        modal.Mount.from_local_file("ppot_0080_22.ptau", remote_path="/root/ppot_0080_22.ptau"),
        modal.Mount.from_local_dir("out", remote_path="/root/out"),  # Change as necessary
    ],
    cpu=60,
    secrets=[modal.Secret.from_name("obl-zkdemo")],
    keep_warm=True,
    volumes={"/root/ptau": vol},
    timeout=20000
)
@modal.wsgi_app()
def flask_app():
    from flask import Flask, request, jsonify
    
    # Define the Flask app
    app = Flask(__name__)

    @app.post("/run")
    def run():
        # Get the contribution from the request
        req = request.get_json()
        contribution = req["contribution"]

        # Debugging: Log working directory
        working_dir = os.getcwd()
        print(f"Working directory: {working_dir}")

        # os.system("snarkjs powersoftau new bn128 22 /root/ptau/pot12_0000.ptau -v")
        # vol.commit()
        
        # os.system(f'echo "{contribution}" | snarkjs powersoftau contribute /root/ptau/pot12_0000.ptau /root/ptau/pot12_0001.ptau --name="First contribution" -v')
        # vol.commit()
        os.system("snarkjs powersoftau prepare phase2 /root/ptau/ppot_0080_22.ptau /root/ptau/pot12_final.ptau -v")
        vol.commit()
        os.system(f"snarkjs groth16 setup /root/coinbase.r1cs /root/ptau/pot12_final.ptau /root/ptau/coinbase_0000.zkey")
        vol.commit()
        

        # Return a success response
        return jsonify({"message": "SNARKJS commands executed successfully", "contribution": contribution}), 200

    return app
