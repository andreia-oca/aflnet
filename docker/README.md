# How to set up AFLNET with Docker

Inside this directory you will find a Makefile for convenience.

To build the docker image named `aflnet`:
```
make build
```

To spin up a container named `aflnet-tutorials`:
```
make run
```
This command will also attach to a shell inside the container.
From here you can start start a fuzzing campaign or you can play around with the tutorials.

To delete the container `aflnet-tutorials`:
```
make clean
```

To clean everything related to Docker images for AFLNET, run:
```
make clean_all
```
