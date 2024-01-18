# NoETL API

NoETL API is a FastAPI application that provides a GraphQL interface for the NoETL Python library. 

## Features

- GraphQL Query and Mutation capabilities.
- Leverage capabilities of NoETL library for data processing and workflows.

## Installation

You can install the application directly from the source:

```shell
git clone https://github.com/noetl/noetl-api.git 
cd noetl-api 
pip install -r requirements.txt
```

## Usage

After installing the NoETL API, you can start the server using FastAPI's ASGI server, Uvicorn:
```shell
uvicorn noetl_api.app:app --reload
```

Once the server is running, point your browser to `http://localhost:8021` to interact with the API using the built-in Swagger UI.

## GraphQL Schema

NoETL API exposes a GraphQL endpoint at `/noetl` where you might send GraphQL queries. The queries and mutations are built around the NoETL data processing.

## Contributing

If you want to improve the NoETL library, whether it's bug reports, documentation, code, design or ideas, please feel free to submit a Pull Request or open an issue.

## License

This project is licensed under the MIT License.

## Contact

If you have any questions or run into any trouble, please raise an issue on the GitHub project page.
