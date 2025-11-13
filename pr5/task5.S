.include "my-macro"             # Подключаем макрос Finish для выхода

.data                           # Инициализированные данные

                                # Матрица A 6x6, заполнена 1..36
A:
    .long 1, 2, 3, 4, 5, 6
    .long 7, 8, 9, 10, 11, 12
    .long 13, 14, 15, 16, 17, 18
    .long 19, 20, 21, 22, 23, 24
    .long 25, 26, 27, 28, 29, 30
    .long 31, 32, 33, 34, 35, 36

error_msg:
    .ascii "Invalid index\n"  # Сообщение об ошибке, 14 байт

.bss                            # Неинициализированные данные

                                # Вектор b (24 байта)
b:
    .space 24

                                # Переменные k и l (по 4 байта)
k:
    .space 4
l:
    .space 4

                                # Буферы для ввода строк (по 10 байт каждый, хватит для "1\n" до "6\n")
input_buf_k:
    .space 10
input_buf_l:
    .space 10

                                # Буфер для вывода (4 байта: '0' + цифра + \n + запас)
output_buf:
    .space 4

.text                           # Секция кода: здесь размещаются инструкции, которые выполнит процессор
.global _start                  # Определяем точку входа в программу (глобальная метка для линкера)

_start:
    nop                         # Пустая инструкция: используется для отладки, чтобы установить точку останова в kdbg

                            # Чтение k: 1) Читаем строку в буфер. 2) Преобразуем в число. 3) Сохраняем в k.

                            # 1) Подготовка и вызов sys_read для k.
    movl $3, %eax               # eax=3: код для чтения (sys_read)
    movl $0, %ebx               # ebx=0: читать из терминала (stdin)
    movl $input_buf_k, %ecx     # ecx = адрес буфера input_buf_k: куда сохранится введённая строка
    movl $10, %edx              # edx=10: сколько байт максимум читать (защита от переполнения)
    int $0x80                   # Прерывание: ядро Linux выполняет sys_read, возвращает кол-во прочитанных байтов в eax (например, "5\n")

                            # 2) Преобразование строки в число: цикл по байтам буфера.
    movl $0, %eax               # eax=0: старт числа
    movl $input_buf_k, %esi     # esi = адрес начала буфера: указатель для чтения байтов по порядку
atoi_k_loop:                # Цикл обработки символов строки.
    movb (%esi), %bl            # bl=текущий байт (символ из строки)
    cmpb $'\n', %bl             # Если '\n' — конец, прыгаем на done
    je atoi_k_done              
    cmpb $0, %bl                # Если 0 — конец, прыгаем на done
    je atoi_k_done              
    subb $'0', %bl              # bl = bl - '0': преобразуем ASCII-символ цифры в числовое значение (0-9)
    imull $10, %eax             # eax = eax * 10: сдвигаем текущее число для добавления новой цифры
    addl %ebx, %eax             # eax = eax + bl: добавляем новую цифру
    incl %esi                   # esi++: перемещаем указатель на следующий байт в буфере
    jmp atoi_k_loop             # Повторяем цикл для следующего символа
atoi_k_done:                
                            # 3) Сохранение числа.
    movl %eax, k                # Сохраняем результат в переменную k в памяти

                            # Повторяем процесс для l: те же шаги 1-3, но с буфером input_buf_l и переменной l.
                            # 1) Подготовка и вызов sys_read для l.
    movl $3, %eax               # eax = 3: sys_read
    movl $0, %ebx               # ebx = 0: stdin
    movl $input_buf_l, %ecx     # ecx = адрес буфера для l
    movl $10, %edx              # edx = 10: длина
    int $0x80                   # Чтение строки для l

                            # 2) Преобразование строки в число.
    movl $0, %eax               
    movl $input_buf_l, %esi     
atoi_l_loop:                
    movb (%esi), %bl            # bl = байт из буфера
    cmpb $'\n', %bl             # Проверка на '\n'
    je atoi_l_done
    cmpb $0, %bl                # Проверка на 0
    je atoi_l_done
    subb $'0', %bl              # Преобразование в цифру
    imull $10, %eax             # *10
    addl %ebx, %eax             # + цифра
    incl %esi                   # Следующий байт
    jmp atoi_l_loop             # Повтор
atoi_l_done:                
                            # 3) Сохранение числа.
    movl %eax, l                # Сохраняем в l

                            # Корректировка индексов для 0-based (вычитаем 1 из k и l).
    decl k                      # k = k - 1: теперь индекс от 0 до 5
    decl l                      # l = l - 1: аналогично

                            # Проверка диапазона k — загружаем и сравниваем.
    movl k, %eax                # eax = k: для временного хранения и сравнения
    cmpl $0, %eax               # Сравниваем с 0
    jl error                    # Если < 0 (jl — jump if less), прыгаем на ошибку
    cmpl $5, %eax               # Сравниваем с 5
    jg error                    # Если > 5 (jg — jump if greater), прыгаем на ошибку
                            # Проверка диапазона l — аналогично.
    movl l, %eax                # eax = l
    cmpl $0, %eax
    jl error
    cmpl $5, %eax
    jg error
                            # Если все проверки прошли — продолжаем программу.
    jmp continue                # Прыжок на метку continue (основная логика)

error:
                            # Обработка ошибки: вывод сообщения и выход.
                            # Подготовка sys_write для печати ошибки.
    movl $4, %eax               # eax = 4: код sys_write (запись в файл/вывод)
    movl $1, %ebx               # ebx = 1: дескриптор stdout (стандартный вывод — экран)
    movl $error_msg, %ecx       # ecx = адрес строки error_msg в .data
    movl $14, %edx              # edx = 14: длина сообщения в байтах
                            # Выполнение вывода.
    int $0x80                   # Ядро печатает сообщение на экран
                            # Завершение программы после ошибки.
    Finish                      # Вызов макроса: sys_exit с кодом 0

continue:
                            # Подготовка цикла: загружаем k и l в регистры, i=0.
    movl k, %edi                # edi = k: фиксированная строка для A[k,i]
    movl l, %esi                # esi = l: фиксированный столбец для A[i,l]
    movl $0, %ebx               # ebx = 0: i = 0 (индекс цикла)

compute_loop:
                            # A[k,i]: вычислить базу строки k.
    movl %edi, %edx             # edx = k
    imull $24, %edx             # edx = k * 24 (смещение строки)
    addl $A, %edx               # edx = A + (k * 24) — начало строки k
    movl (%edx, %ebx,4), %eax   # eax = A[k][i] (base=edx, index=ebx=i, scale=4)

                            # A[i,l]: вычислить базу строки i.
    movl %ebx, %edx             # edx = i
    imull $24, %edx             # edx = i * 24
    addl $A, %edx               # edx = A + (i * 24) — начало строки i
    addl (%edx, %esi,4), %eax   # eax += A[i][l] (base=edx, index=esi=l, scale=4)

                            # Сохранение в b[i].
    movl %eax, b(,%ebx,4)       # b[i] = eax (base=b, index=ebx, scale=4)

    incl %ebx                   # i++ (ebx +=1)
    cmpl $6, %ebx               # i == 6? (конец цикла)
    jne compute_loop            # Нет — повторяем

    # Вывод b: цикл i=0..5, простой itoa (2 цифры + \n), sys_write.
    movl $0, %ebp               # ebp=0: i для вывода

output_loop:
    movl b(,%ebp,4), %eax       # eax = b[i]

    # itoa: div 10 (единицы), div 10 (десятки), пишется в буфер.
    movl $output_buf, %edi      # edi=начало буфера
    movl $10, %ecx              # ecx=10
    xorl %edx, %edx             # edx=0
    divl %ecx                   # eax=десятки, edx=единицы
    addb $'0', %dl              # dl='0' + единицы
    movb %dl, 1(%edi)           # Единицы в буфер[1]
    addb $'0', %al              # al='0' + десятки (ведущий '0' если <10)
    movb %al, (%edi)            # Десятки в буфер[0]
    movb $'\n', 2(%edi)         # \n в буфер[2]
    movb $0, 3(%edi)            # Запас (null)

    # sys_write: 4 байта на stdout.
    movl $4, %eax               # sys_write
    movl $1, %ebx               # stdout
    movl $output_buf, %ecx      # буфер
    movl $4, %edx               # длина 4 байта
    int $0x80                   # Печать

    incl %ebp                   # i++
    cmpl $6, %ebp               # i==6?
    jne output_loop             # Нет — повтор

    Finish                      # Конец
.end                        # Конец исходного текста программы