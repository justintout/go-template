# Go app template build environment

Combination of the [thockin/go-build-template](https://github.com/thockin/go-build-template) and (more heavily) the layout that [jessfraz](https://github.com/jessfraz) uses for her projects. 

It is my current project skeleton. The build leans very heavily on the Makefile, and you can run `make help` to see the commands.  

This has only been tested on OS X.

## Building

Run `make build` to compile the app/package. Run `make` to go through full testing and install the app/package.

Run `make clean` to clean up.

More customization needs to be done in the Makefile to handle Dockerization and pushing to the Docker Hub. This work will come from [thockin/go-build-template](https://github.com/thockin/go-build-template). 
