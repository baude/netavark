#!/usr/bin/env bats   -*- bats -*-
#
# bridge driver tests with iptables firewall driver
#

load helpers

fw_driver=iptables

@test "check iptables driver is in use" {
    RUST_LOG=netavark=info run_netavark --file ${TESTSDIR}/testfiles/simplebridge.json setup $(get_container_netns_path)
    assert "${lines[0]}" "==" "[INFO  netavark::firewall] Using iptables firewall driver" "iptables driver is in use"
}

@test "$fw_driver - internal network" {

# grab the iptables info before running the test
run_in_host_netns iptables -t nat -nvL
before="$output"

run_netavark --file ${TESTSDIR}/testfiles/internal.json setup $(get_container_netns_path)

run_in_host_netns iptables -t nat -nvL
after="$output"
assert "$before" == "$after" "make sure tables have not changed"

run_in_container_netns ip route show
assert "default" "!~" "$output" "No default route for internal networks"


expected_rc=1 run_in_container_netns ping -c 1 10.88.0.1
echo $output
assert "trrue" == "false"

#mac=$(jq -r '.podman.interfaces.eth0.mac_address' <<<"$result")
# check that interface exists
#run_in_container_netns ip -j --details link show eth0
#link_info="$output"
#assert_json "$link_info" ".[].address" == "$mac" "MAC matches container mac"
#assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Container interface is up"
#assert_json "$link_info" ".[].linkinfo.info_kind" == "veth" "Container interface is a veth device"

#ipaddr="10.88.0.2/16":w
#
#run_in_container_netns ip addr show eth0
#        assert "$output" =~ "$ipaddr" "IP address matches container address"
#assert_json "$result" ".podman.interfaces.eth0.subnets[0].ipnet" == "$ipaddr" "Result contains correct IP address"
#
#run_in_host_netns ip -j --details link show podman0
#link_info="$output"
#assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Host bridge interface is up"
#assert_json "$link_info" ".[].linkinfo.info_kind" == "bridge" "The bridge interface is actually a bridge"
#
#ipaddr="10.88.0.1"
#run_in_host_netns ip addr show podman0
#        assert "$output" =~ "$ipaddr" "IP address matches bridge gateway address"
#assert_json "$result" ".podman.interfaces.eth0.subnets[0].gateway" == "$ipaddr" "Result contains gateway address"

# check that the loopback adapter is up
#run_in_container_netns ip addr show lo
#        assert "$output" =~ "127.0.0.1" "Loopback adapter is up (has address)"
#
#run_in_host_netns ping -c 1 10.88.0.2

# TODO check iptables
# iptables -L ...

run_netavark --file ${TESTSDIR}/testfiles/internal.json teardown $(get_container_netns_path)
}
@test "$fw_driver - simple bridge" {
run_netavark --file ${TESTSDIR}/testfiles/simplebridge.json setup $(get_container_netns_path)
    result="$output"
    assert_json "$result" 'has("podman")' == "true" "object key exists"

    mac=$(jq -r '.podman.interfaces.eth0.mac_address' <<<"$result")
    # check that interface exists
    run_in_container_netns ip -j --details link show eth0
    link_info="$output"
    assert_json "$link_info" ".[].address" == "$mac" "MAC matches container mac"
    assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Container interface is up"
    assert_json "$link_info" ".[].linkinfo.info_kind" == "veth" "Container interface is a veth device"

    ipaddr="10.88.0.2/16"
    run_in_container_netns ip addr show eth0
    assert "$output" =~ "$ipaddr" "IP address matches container address"
    assert_json "$result" ".podman.interfaces.eth0.subnets[0].ipnet" == "$ipaddr" "Result contains correct IP address"

    run_in_host_netns ip -j --details link show podman0
    link_info="$output"
    assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Host bridge interface is up"
    assert_json "$link_info" ".[].linkinfo.info_kind" == "bridge" "The bridge interface is actually a bridge"

    ipaddr="10.88.0.1"
    run_in_host_netns ip addr show podman0
    assert "$output" =~ "$ipaddr" "IP address matches bridge gateway address"
    assert_json "$result" ".podman.interfaces.eth0.subnets[0].gateway" == "$ipaddr" "Result contains gateway address"

    # check that the loopback adapter is up
    run_in_container_netns ip addr show lo
    assert "$output" =~ "127.0.0.1" "Loopback adapter is up (has address)"

    run_in_host_netns ping -c 1 10.88.0.2

    # TODO check iptables
    # iptables -L ...

    run_netavark --file ${TESTSDIR}/testfiles/simplebridge.json teardown $(get_container_netns_path)
}

@test "$fw_driver - ipv6 bridge" {
    run_netavark --file ${TESTSDIR}/testfiles/ipv6-bridge.json setup $(get_container_netns_path)
    result="$output"
    assert_json "$result" 'has("podman1")' == "true" "object key exists"

    mac=$(jq -r '.podman1.interfaces.eth0.mac_address' <<<"$result")
    # check that interface exists
    run_in_container_netns ip -j --details link show eth0
    link_info="$output"
    assert_json "$link_info" ".[].address" == "$mac" "MAC matches container mac"
    assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Container interface is up"
    assert_json "$link_info" ".[].linkinfo.info_kind" == "veth" "Container interface is a veth device"

    ipaddr="fd10:88:a::2/64"
    run_in_container_netns ip addr show eth0
    assert "$output" =~ "$ipaddr" "IP address matches container address"
    assert_json "$result" ".podman1.interfaces.eth0.subnets[0].ipnet" == "$ipaddr" "Result contains correct IP address"

    run_in_host_netns ip -j --details link show podman1
    link_info="$output"
    assert_json "$link_info" '.[].flags[] | select(.=="UP")' == "UP" "Host bridge interface is up"
    assert_json "$link_info" ".[].linkinfo.info_kind" == "bridge" "The bridge interface is actually a bridge"

    ipaddr="fd10:88:a::1"
    run_in_host_netns ip addr show podman1
    assert "$output" =~ "$ipaddr" "IP address matches bridge gateway address"
    assert_json "$result" ".podman1.interfaces.eth0.subnets[0].gateway" == "$ipaddr" "Result contains gateway address"

    # check that the loopback adapter is up
    run_in_container_netns ip addr show lo
    assert "$output" =~ "127.0.0.1" "Loopback adapter is up (has address)"

    run_in_host_netns ping6 -c 1 fd10:88:a::2

    run_netavark --file ${TESTSDIR}/testfiles/ipv6-bridge.json teardown $(get_container_netns_path)
}

@test "$fw_driver - port forwarding ipv4 - tcp" {
    test_port_fw
}

@test "$fw_driver - port forwarding ipv6 - tcp" {
    test_port_fw ip=6
}

@test "$fw_driver - port forwarding dualstack - tcp" {
    test_port_fw ip=dual
}

@test "$fw_driver - port forwarding ipv4 - udp" {
    test_port_fw proto=udp
}

@test "$fw_driver - port forwarding ipv6 - udp" {
    test_port_fw ip=6 proto=udp
}

@test "$fw_driver - port forwarding dualstack - udp" {
    test_port_fw ip=dual proto=udp
}

@test "$fw_driver - port forwarding ipv4 - sctp" {
    setup_sctp_kernel_module
    test_port_fw proto=sctp
}

@test "$fw_driver - port forwarding ipv6 - sctp" {
    setup_sctp_kernel_module
    test_port_fw ip=6 proto=sctp
}

@test "$fw_driver - port forwarding dualstack - sctp" {
    setup_sctp_kernel_module
    test_port_fw ip=dual proto=sctp
}
