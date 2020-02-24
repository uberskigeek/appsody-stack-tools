# appsody-stack-tools
testing tools for appsody java-openliberty stack

## Prerequisites
The test script requires jq to be installed
- for Mac brew install jq
- for linux apt-get install jq
- for Red has yum install jq

The stack will be initialized in */tmp/test_stack name*
(e.g. /tmp/test_java-openliberty) so you will need to have */tmp* available on
your system

## Running the stack tester
To test a stack issue the command *test-stack.sh repo stack template* (e.g.
test-stack.sh appsody-hub java-openliberty default)
The template parameter is optional. If not provided the default template will be
used.  Currently the java-openliberty stack default application URL is checked
along with the MP Metrics Health URL.
