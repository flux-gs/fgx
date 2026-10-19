; M3: every conditional short-branch mnemonic targeting the same label.
                MX      %00
                BEQ     done
                BNE     done
                BCC     done
                BCS     done
                BMI     done
                BPL     done
                BVC     done
done            RTS
