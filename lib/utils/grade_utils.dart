String? mapGradeIntToString(int? grade) {
  if (grade == null) return null;
  const gradeMap = {
    1: 'اول',
    2: 'دوم',
    3: 'سوم',
    4: 'چهارم',
    5: 'پنجم',
    6: 'ششم',
    7: 'هفتم',
    8: 'هشتم',
    9: 'نهم',
    10: 'دهم',
    11: 'یازدهم',
    12: 'دوازدهم',
  };
  return gradeMap[grade];
}

int? mapGradeStringToInt(String? grade) {
  if (grade == null) return null;
  const gradeMap = {
    'اول': 1,
    'دوم': 2,
    'سوم': 3,
    'چهارم': 4,
    'پنجم': 5,
    'ششم': 6,
    'هفتم': 7,
    'هشتم': 8,
    'نهم': 9,
    'دهم': 10,
    'یازدهم': 11,
    'دوازدهم': 12,
  };
  return gradeMap[grade];
}
