from setuptools import setup, find_packages
from setuptools.command.install import install as InstallCommand
import subprocess

class SpacyDownloadAndInstallCommand(InstallCommand):
    def run(self):
        subprocess.call(["python", "spacy_download.py"])
        super().run()

def read_requirements():
  with open("requirements.txt", "r") as file:
    return file.read().splitlines()

with open("README.md", "r") as readme:
    long_description = readme.read()

setup(
    name="noetl-api",
    version="0.1.6",
    author="NoETL Team",
    description="NoETL-API: A FastAPI and GraphQL application for managing NoETL workflows",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=find_packages(),
    install_requires=read_requirements(),
    cmdclass={
        "install": SpacyDownloadAndInstallCommand,
    },
    entry_points={
        "console_scripts": [
            "noetl-api = noetl_api.app:main",
        ],
    },
)
