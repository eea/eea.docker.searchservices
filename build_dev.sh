#!/usr/bin/python

from argparse import ArgumentParser
import sys
import subprocess


RIVER_PROJECTS = {
    'elastic': 'eeacms/elastic:dev',
}

SEARCH_PROJECTS = {
    'aide': 'eeacms/aide:dev', 
    'eeasearch': 'eeacms/eeasearch:dev', 
    'pam': 'eeacms/pam:dev',
}

PATH_PROJECTS = {
    'aide': 'eea.docker.aide',
    'eeasearch': 'eea.docker.eeasearch',
    'pam': 'eea.docker.pam',
    'elastic': 'eea.docker.elastic',
}

RIVER_DEV_BUILD = ('echo "Building River Plugin" && '
                   'pushd ./eea.elasticsearch.river.rdf &> /dev/null && '
                   'mvn clean install && '
                   'popd && '
                   'echo "Building Image" && '
                   'PLUGIN=$(find ./eea.elasticsearch.river.rdf -name "eea-rdf-river-plugin-*.zip") && '
                   'cp $PLUGIN ./{0}/eea-rdf-river.zip && '
                   'pushd ./eea.docker.{1} && '
                   'docker build -f ./Dockerfile.dev -t eeacms/{1}:dev ./ && '
                   'popd && '
                   'rm ./{0}/eea-rdf-river.zip')

SEARCH_DEV_BUILD = ('rm -rf ./{0}/eea-searchserver && '
                    'cp -r ./eea.searchserver.js ./{0}/eea-searchserver && '
                    'pushd ./eea.docker.{1} && '
                    'docker build -t "eeacms/{1}:dev" -f ./Dockerfile.dev . && '
                    'popd && '
                    'rm -rf ./{0}/eea-searchserver')

DOCKER_BUILD = 'docker build -t {0} ./{1}'

def main():
    parser = ArgumentParser()
    parser.add_argument('projects', metavar="PROJECT", nargs="*", 
                        help="Specify one or more projects to build. Can be one of {0}.\n If no arguments are specified, all projects will be built.".format(
                        ', '.join(RIVER_PROJECTS.keys() + SEARCH_PROJECTS.keys())
                        ))
    parser.add_argument('-s', '--search', const=True, action='store_const', 
                        help="Use development version of EEA.SEARCHSERVER.JS server")
    parser.add_argument('-r', '--river', const=True, action='store_const', 
                        help="Use development version of RIVER.RDF plugin")
    args = parser.parse_args()

    print "Projects", args.projects
    print "River", args.river
    print "Search", args.search
            
    mergeList = ', '.join(RIVER_PROJECTS.keys() + SEARCH_PROJECTS.keys()) 
    
    commands_to_run = []
    if not args.projects:
        args.projects = RIVER_PROJECTS.keys() + SEARCH_PROJECTS.keys()
    
    for project in args.projects:
        if project not in mergeList:
            print
            print "Invalid project {0}".format(project)
            print "Run without arguments, to build all, or insert only the following for specific project: {0}".format(mergeList)
            print
            sys.exit(1)
        
        if project in SEARCH_PROJECTS:
            if args.search:
	        commands_to_run.append(SEARCH_DEV_BUILD.format(PATH_PROJECTS[project], project))
            else:
                commands_to_run.append(DOCKER_BUILD.format(SEARCH_PROJECTS[project], PATH_PROJECTS[project]))
            if args.river:
                print "Warning! -r | --river flag option will be ignored for {0}!".format(project)
        
        if project in RIVER_PROJECTS:
            if args.river:
                commands_to_run.append(RIVER_DEV_BUILD.format(PATH_PROJECTS[project], project))
            else:
                commands_to_run.append(DOCKER_BUILD.format(RIVER_PROJECTS[project], PATH_PROJECTS[project]))
            if args.search:
                print "Warning! -s | --search flag option will be ignored for {0}!".format(project)
    print
    
    for cmd in commands_to_run:
        print "run command: ", cmd
        res = subprocess.call(cmd, shell=True, executable="/bin/bash")
        if res != 0:
            print "Failure in building ..."
            sys.exit(1)
    
    print "Done"
    

if __name__ == "__main__":
    main()
