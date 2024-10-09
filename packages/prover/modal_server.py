import modal
import logging

app = modal.App("obl-zkproverv1.0.1")

image = modal.Image.from_dockerfile("Dockerfile")


@app.function(
    image=image,
    mounts=[
        modal.Mount.from_local_python_packages("core"),
        modal.Mount.from_local_file("circom_proofgen.sh", remote_path="/root/circom_proofgen.sh"),
    ],
    cpu=60,
    gpu="H100",
    secrets=[modal.Secret.from_name("obl-zkdemo")],
    keep_warm=True,
)
@modal.wsgi_app()
def flask_app():
    from flask import Flask, request, jsonify
    import random
    import sys
    import json
    import os
    from core import (
        gen_email_auth_proof,
    )

    app = Flask(__name__)

    @app.post("/prove/email_auth")
    def prove_email_auth():
        print("prove_email_auth")
        req = request.get_json()
        input = req["input"]
        circuit_name = req["circuit_name"]
        print(req)
        nonce = random.randint(
            0,
            sys.maxsize,
        )
        print(nonce)
        proof = gen_email_auth_proof(str(nonce), False, input, circuit_name)
        print(proof)
        return jsonify(proof)

    return app
