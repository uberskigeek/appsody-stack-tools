# appsody-stack-tools
This currently consists of the test_stack.sh script. This script runs tests in
two different scenarios.
First it can initialize a project with an appsody stack then do an appsody run
checking the health URL for a status of up and an application URL that provides
a response code of 200 when successful. This will then be followed with an
appsody deploy testing the same URLs albeit at different ports.  
Second it can take a git repository containing one or more projects that were
created using appsody init and run the same tests against each of the appsody
projects in the repository. Any project that contains the file .appsody-nolocal
will only be tested with appsody deploy

When initializing a project with an appsody stack the project will be created
in */tmp/test_stack_name*.
When cloning git repositories they will be cloned to */tmp/gitRepositoryName*



## test-stack.sh options
### Initializing a new project with an apposdy Stack
- -a or --appsody_repo - the appsody repo the stack will be pulled from
- -s or --stack - the name of the stack to use.
- -t or --template - the name of the template to use if none is defined the
default will be used.

example: `./test-stack.sh -a appsody-hub -s java-openliberty -t default`

### Using a project from a git repository
- -g or --gitrepo - the git repository you want to clone (copied from the clone
   repository button on github)
- -b or --branch - the specific branch of the repo you'd like to copy. This is
  optional

example `./test-stack.sh -g git@github.com:uberskigeek/appsody-projects.git -b alternate`

### Options available for either of the above cases
- -c or --contextRoot - When testing the application this value will be used to
contact the application. It is expected that a response code of 200 will be
received when the application is available.

### Mutual exclusivity
If -a, -s, or -t are used along with -g and -b then the -g and -b parameters
will take precedence and the other options will be ignored.

## Prerequisites
The test script requires jq to be installed
- for Mac `brew install jq`
- for linux `apt-get install jq`
- for Red hat `yum install jq`
