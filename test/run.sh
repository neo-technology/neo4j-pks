#!/bin/bash
# Print commands as they're executed.
# set -x

if [ -z $NAME ] ; then
    echo "The NAME env var must be set"
    exit 1
fi

if [ -z $CORES ] ; then
    echo "Env var CORES must be set"
    exit 1
fi

if [ -z $READ_REPLICAS ] ; then
    echo "Env var READ_REPLICAS must be set"
    exit 1
fi

# Configuration with defaults specified
HTTP_PORT="${HTTP_PORT:-7474}"
HTTPS_PORT="${HTTPS_PORT:-7473}"
BOLT_PORT="${BOLT_PORT:-7687}"
NAMESPACE="${NAMESPACE:-default}"

host="$NAME-neo4j.$NAMESPACE.svc.cluster.local"
replica_host="$NAME-neo4j-readreplica-svc.$NAMESPACE.svc.cluster.local"
echo "HOST $host"
# This endpoint proves availability of the overall service
endpoint="http://$host:$HTTP_PORT"
echo "ENDPOINT $endpoint"
# Mounted secret
NEO4J_SECRETS_PASSWORD=$(cat /secret/neo4j-password)
auth="neo4j:${NEO4J_SECRETS_PASSWORD}"
echo "AUTH $auth"
echo "CORES $CORES"
echo "RRs $READ_REPLICAS"
echo "NAMESPACE $NAMESPACE"

# When test resources are deployed cluster hasn't had a chance to form yet.
# This polls in a loop waiting for cluster to become available, and gives up/fails
# tests if it doesn't work within attempts.
attempt=0
attempts=100

while true; do
    attempt=$[$attempt + 1]
    curl -s -I $endpoint/ | grep "200 OK"
    if [ $? -eq 0 ] ; then
    echo "✔️ Neo4j is up at attempt $attempt; HTTP port $HTTP_PORT"
    break
    fi

    if [ $attempt -ge "$attempts" ]; then
    echo "❌ REST API seems not to be coming up, giving up after $attempts attempts"
    exit 1
    fi

    echo "Sleeping; not up yet after $attempt attempts"
    sleep 5
done

# At this point the service endpoint proves that at least one host is up.
# Provide just a bit more time for all of them to finish coming up because we'll
# be testing them individually.
echo "Waiting for formation to finish"
sleep 10

# Pass index ID to get hostname for that pod.
function core_hostname {
    echo "$NAME-neo4j-core-$1.$NAME-neo4j.$NAMESPACE.svc.cluster.local"
}

function replica_hostname {
    echo "$NAME-replica-$1.$NAME-readreplica.$NAMESPACE.svc.cluster.local"
}

test_index=0

function succeed {
    echo "✔️  Test $test_index: $1"
    test_index=$[$test_index + 1]
}

function fail {
    echo "❌ Test $test_index: $1"
    echo "Additional information: " "$2"
    exit 1
}

function cypher {
    # Use routing driver by default, send query wherever.
    DEFAULT_ENDPOINT="bolt+routing://$host:$BOLT_PORT"

    # If caller specified, use a specific endpoint to route a query to just one node.
    ENDPOINT=${2:-$DEFAULT_ENDPOINT}

    echo "$1" | cypher-shell --encryption true -u neo4j -a "$ENDPOINT" -p "$NEO4J_SECRETS_PASSWORD"
}

function runtest {
    # Use routing driver by default, send query wherever.
    DEFAULT_ENDPOINT="bolt+routing://$host:$BOLT_PORT"

    # If caller specified, use a specific endpoint to route a query to just one node.
    ENDPOINT=${3:-$DEFAULT_ENDPOINT}

    echo "Running $1 against $ENDPOINT"
    output=$(cypher "$2" "$3")

    if [ $? -eq 0 ] ; then  
    succeed "$1"
    else
    echo "Last output -- $output"
    fail "$1" "$output"
    fi
}

test="HTTPS is available, port $HTTPS_PORT"
curl --insecure https://$host:$HTTPS_PORT/
if [ $? -eq 0 ] ; then
    succeed "$test"
else
    fail "$test"
fi

echo "Basic topology upfront"
cypher "CALL dbms.cluster.overview();"

runtest "Bolt is available, port $BOLT_PORT"               "RETURN 'yes';"
runtest "Basic read queries, encrypted connection"         "MATCH (n) RETURN COUNT(n);"
runtest "Database is in clustered mode"                    "CALL dbms.cluster.overview();" 
runtest "Cluster accepts writes"                           'CREATE (t:TestNode) RETURN count(t);'

# Data from server on cluster topology.
topology=$(cypher "CALL dbms.cluster.overview();")
echo "TOPOLOGY $topology"

# LEADERS
leaders=$(echo $topology | grep -o LEADER | wc -l)
test="Cluster has 1 leader"
if [ $leaders -eq 1 ] ; then
    succeed "$test"
else
    fail "$test" "$leaders leaders"
fi

# FOLLOWERS
followers=$(echo $topology | grep -o FOLLOWER | wc -l)
test="Cluster has 1-CORES followers"
if [ $followers -eq $((CORES-1)) ] ; then
    succeed "$test"
else
    fail "$test" "$followers followers"
fi

# REPLICAS
read_replicas=$(echo $topology | grep -o READ_REPLICA | wc -l)
test="Cluster has $READ_REPLICAS read replicas"
if [ $read_replicas -eq $READ_REPLICAS ] ; then
    succeed "$test"
else
    fail "$test" "$read_replicas replicas"
fi

# Each core is individually up and configured.
for id in $(seq 0 $((CORES - 1))); do
    core_host=$(core_hostname $id)
    core_endpoint="bolt://$core_host:$BOLT_PORT"

    test="Core host $id of $CORES -- $core_endpoint is available"
    runtest "$test" "MATCH (n) RETURN COUNT(n);" "$core_endpoint"

    test="Core host $id of $CORES -- $core_endpoint has APOC installed correctly"
    runtest "$test" "RETURN apoc.version();" "$core_endpoint"

    test="Core host $id of $CORES -- $core_endpoint has Graph Algorithms installed correctly"
    runtest "$test" "CALL algo.list();" "$core_endpoint"
done

# Replicas are up and configured.
replica_endpoint="bolt://$replica_host:$BOLT_PORT"
test="Replica host -- $replica_endpoint is available"
runtest "$test" "MATCH (n) RETURN COUNT(n);" "$replica_endpoint"

test="Replica host -- $replica_endpoint has APOC installed correctly"
runtest "$test" "RETURN apoc.version();" "$replica_endpoint"

# Test for data replication.
runtest "Sample canary write" 'CREATE (c:Canary) RETURN count(c);'
echo "Sleeping a few seconds to permit replication"
sleep 5

# Check each core, count the canary writes. They should all agree.
for id in $(seq 0 $((CORES - 1))); do
    core_host=$(core_hostname $id)
    # Use bolt driver, not routing driver, to ensure that test verifies data
    # exists on this host.
    core_endpoint="bolt://$core_host:$BOLT_PORT"
    test="Core host $id has the canary write"
    result=$(cypher "MATCH (c:Canary) WITH count(c) as x where x = 1 RETURN x;" "$core_endpoint")
    exit_code=$?
    if [ $exit_code -eq 0 ] ; then
    # Check that the data is there.
    found_results=$(echo "$result" | grep -o 1 | wc -l)

    if [ $found_results -eq 1 ] ; then
        succeed "$test"
    else 
        fail "$test" "Canary read did not return data -- $found_results found results from $result"
    fi
    else
    fail "$test" "Canary read failed to execute -- exit code $exit_code / RESULT -- $result"
    fi
done

test="Read Replica has the canary write"
result=$(cypher "MATCH (c:Canary) WITH count(c) as x where x = 1 RETURN x;" "$replica_endpoint")
exit_code=$?
if [ $exit_code -eq 0 ] ; then
    found_results=$(echo "$result" | grep -o 1 | wc -l)

    if [ $found_results -eq 1 ] ; then
    succeed "$test" "Canary read did not return data -- $found_results found results from $result"
    else
    fail "$test" 
    fi
else
    fail "$test" "Canary read did not return data -- exit code $exit_code / RESULT -- $result"
fi

echo "All good; testing completed"
exit 0
