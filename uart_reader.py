import serial
import time
import numpy as np
import cv2

# for debug
# 63488 -red
# 2016 - green
# 31 - blue

reg = []

slave_address = bytes.fromhex("21")

with open("new_registers_2.csv", "r", encoding="utf-8") as f:
    for line in f:
        if line[:2] == "//" or line[0] == "#":
            continue

        line = line.strip().split(",")
        reg.append((bytes.fromhex(line[0]), bytes.fromhex(line[1])))

# open serial
ser = serial.Serial(
    port='/dev/ttyUSB2',
    baudrate=115200  #,
)

if(not ser.isOpen()):
    ser.open()


# size of an image
img_w = 240
img_h = 320

commands = {
    "begin capture": 1,
    "end capture": 2,
    "send regs": 3
}

waiting = 1
while waiting:
    in_command = input(">> ")
    if in_command == 'exit':
        ser.close()
        exit()

    elif in_command == "send regs":
        bytes_arr = commands[in_command].to_bytes(1,"little")
        time.sleep(0.67)
        for elem in reg:
            ser.write(bytes_arr)
            time.sleep(0.1)

            ser.write(slave_address)
            time.sleep(0.1)

            ser.write(elem[0])
            time.sleep(0.1)

            ser.write(elem[1])
            time.sleep(0.1)



        time.sleep(0.67)



    elif in_command == "begin capture":  # not working for now
        bytes_arr = commands[in_command].to_bytes(1,"little")
        ser.write(bytes_arr)
        ser.write(slave_address)

    elif in_command == "end capture": # not working for now
        bytes_arr = commands[in_command].to_bytes(1,"little")
        ser.write(bytes_arr)
        ser.write(slave_address)

    elif in_command == "custom":
        for i in range(4):
            ttt = input(f"Byte {i}: ")
            to_send_byte = bytes.fromhex(ttt)
            ser.write(to_send_byte)

    elif in_command == "continue":
        waiting = 0
    else:
        print("Wrong_command")


time.sleep(2)
print("starting")
while True:

    output_1_byte = b""
    output_2_byte = b""

    img_to_save = np.zeros((img_w, img_h, 3))


    counter = 0
    h_counter = 0
    w_counter = 0

    while(counter < (img_w*img_h)-1 ):
        output_1_byte = ser.read(1)
        output_2_byte = ser.read(1)

        output_1_byte = int.from_bytes(output_1_byte, "big")
        output_2_byte = int.from_bytes(output_2_byte, "big")

        if (counter % 100) == 0:
            print(f"{counter}/{(img_w*img_h)-1 }")


        counter += 1

        w_counter += 1

        if w_counter >= img_w:
            h_counter += 1
            w_counter = 0

        if output_1_byte != b'' and output_2_byte != b'':
            red_c = output_1_byte&0xF8
            green_c = ((output_1_byte&0x07)<<5)+((output_2_byte&0xE0)>>5)
            blue_c = (output_2_byte&0x1F)<<3

            # opencv is BGR
            img_to_save[w_counter, h_counter, 0] = blue_c
            img_to_save[w_counter, h_counter, 1] = green_c
            img_to_save[w_counter, h_counter, 2] = red_c


    cv2.imwrite("test.png", img_to_save)
   # cv2.imshow('frame' , img_to_save)   # not tested
    print("frame", output_1_byte, output_2_byte)
