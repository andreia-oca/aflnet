.PHONY: build run clean clean_all  

build:
	docker image build -t aflnet:latest .

run: build
	docker run -it --name aflnet_tutorials aflnet:latest /bin/bash

attach:
	docker exec -it aflnet_tutorials /bin/bash

clean:
	docker rm -f aflnet_tutorials

clean_all:
	docker rm -f aflnet_tutorials
	docker image rm aflnet:latest
