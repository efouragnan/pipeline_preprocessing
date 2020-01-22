read $1
read-loop $2
register
write $3
end-loop
bye