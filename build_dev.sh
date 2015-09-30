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

RIVER_DEV_BUILD = '{0}/build_dev.sh {0}/../eea.elasticsearch.river.rdf'
SEARCH_DEV_BUILD = '{0}/build_dev.sh {0}/../eea.searchserver.js'
DOCKER_BUILD = 'docker build -t {0}'

def main():
    parser = ArgumentParser()
    parser.add_argument('projects', metavar="PROJECT", nargs="+", 
                        help="Specify one or more projects to build. Can be one of {0}".format(
                        ', '.join(RIVER_PROJECTS.keys() + SEARCH_PROJECTS.keys())
                        ))
    parser.add_argument('-s', '--search', const=True, action='store_const', 
                        help="Use development version of EEA.SEARCHSERVER.JS server")
    parser.add_argument('-r', '--river', const=True, action='store_const', 
                        help="Use development version of RIVER.RDF plugin")
    args = parser.parse_args()

    #print "Projects", args
    #print "River", args.river
    #print "Search", args.search
            
    mergeList = ', '.join(RIVER_PROJECTS.keys() + SEARCH_PROJECTS.keys()) #SEARCH_PROJECTS.copy()
    #mergeList.update(RIVER_PROJECTS)
    
    for name in args.projects:
        if name not in mergeList:
            print
            #print "Insert only the following arguments: {0}".format(", ".join(mergeList.keys()))
            print "Insert only the following arguments: {0}".format(mergeList)
            print
            sys.exit(1)
    
#    if not args.projects:
#        print "Please specify the "
#        parser.print_help()
#        sys.exit(1)
    
    if args.search and not set(SEARCH_PROJECTS.keys()).intersection(args.projects):
        print 
        print "If you include local EEA.SEARCHSERVER.JS, you should include one of {0}"\
            .format(', '.join(SEARCH_PROJECTS.keys()))
        print 
        parser.print_help()
        sys.exit(1)

    if args.river and not set(RIVER_PROJECTS.keys()).intersection(args.projects):
        print 
        print "If you include RIVER.RDF plugin, you should include {0}"\
            .format(', '.join(RIVER_PROJECTS.keys()))
        print 
        parser.print_help()
        sys.exit(1)

    # in case the river flag is included in command line
    #   cd elastic
    #   build_dev ../${RIVER}

    # in case there is no flag on the command line
    #   cd elastic
    #   docker build -t eeacms/elastic:dev .

    for project in RIVER_PROJECTS:
        if project in args.projects:
            # build the project
            if args.river:
                print "run command : ", RIVER_DEV_BUILD.format(PATH_PROJECTS[project])
                res = subprocess.call(RIVER_DEV_BUILD.format(PATH_PROJECTS[project]), shell=True)
                if res == 0:
                    print "Failure in building ..."
                    sys.exit(1)
            else:
                print "run command : ", DOCKER_BUILD.format(RIVER_PROJECTS[project])
                res = subprocess.call(DOCKER_BUILD.format(RIVER_PROJECTS[project]), shell=True)
                if res == 0:
                    print "Failure in building ..."
                    sys.exit(1)

    for project in SEARCH_PROJECTS:
        if project in args.projects:
            # build the project
            if args.search:
                print "run command : ", SEARCH_DEV_BUILD.format(PATH_PROJECTS[project])
               res = subprocess.call(SEARCH_DEV_BUILD.format(PATH_PROJECTS[project]), shell=True)
               if res == 0:
                   print "Failure in building ..."
                   sys.exit(1)
            else:
                print "run command : ", DOCKER_BUILD.format(SEARCH_PROJECTS[project])
                res = subprocess.call(DOCKER_BUILD.format(SEARCH_PROJECTS[project]), shell=True)
                if res == 0:
                    print "Failure in building ..."
                    sys.exit(1)


if __name__ == "__main__":
    main()
